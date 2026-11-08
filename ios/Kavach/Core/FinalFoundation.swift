import Foundation
import Security
import CryptoKit

enum FeatureAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
    case mock
    case blocked(String)
}

/// Stores an opaque session blob; the backend adapter owns its schema.
protocol SecureCredentialStore: Sendable {
    func read() async throws -> Data?
    func write(_ data: Data) async throws
    func clear() async throws
}

struct CredentialStoreError: Error, Equatable {
    let status: OSStatus
}

actor KeychainCredentialStore: SecureCredentialStore {
    private let service: String
    private let account: String

    init(bundleIdentifier: String, account: String = "user-session") {
        precondition(!bundleIdentifier.isEmpty && !account.isEmpty)
        service = bundleIdentifier + ".session"
        self.account = account
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    func read() throws -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError(status: status) }
        guard let data = result as? Data else { throw CredentialStoreError(status: errSecDecode) }
        return data
    }

    func write(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insertion = query.merging(attributes) { _, new in new }
            let added = SecItemAdd(insertion as CFDictionary, nil)
            guard added == errSecSuccess else { throw CredentialStoreError(status: added) }
        } else if status != errSecSuccess {
            throw CredentialStoreError(status: status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError(status: status)
        }
    }
}

struct AppleSignInNonce: Sendable {
    let rawValue: String
    var sha256Value: String { Self.sha256(rawValue) }

    static func generate() throws -> Self {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw CredentialStoreError(status: status) }
        return .init(rawValue: bytes.map { String(format: "%02x", $0) }.joined())
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct ServerSentEvent: Equatable, Sendable {
    let id: String
    let event: String
    let data: String
}

enum ServerSentEventParseError: Error { case lineTooLarge, eventTooLarge }

/// Parses transport framing only; event payload decoding belongs to the backend adapter.
struct ServerSentEventParser {
    private(set) var lastEventID = ""
    private(set) var retryMilliseconds: UInt64?
    private let maximumLineBytes: Int
    private let maximumEventBytes: Int
    private var line: [UInt8] = []
    private var dataLines: [String] = []
    private var eventName = ""
    private var eventBytes = 0
    private var afterCR = false
    private var firstLine = true

    init(maximumLineBytes: Int = 64 * 1024, maximumEventBytes: Int = 256 * 1024) {
        precondition(maximumLineBytes > 0 && maximumEventBytes > 0)
        self.maximumLineBytes = maximumLineBytes
        self.maximumEventBytes = maximumEventBytes
    }

    mutating func append(_ chunk: Data) throws -> [ServerSentEvent] {
        var events: [ServerSentEvent] = []
        for byte in chunk {
            if afterCR {
                afterCR = false
                if byte == 10 { continue }
            }
            if byte == 10 || byte == 13 {
                if let event = try consumeLine() { events.append(event) }
                afterCR = byte == 13
            } else {
                guard line.count < maximumLineBytes else { throw ServerSentEventParseError.lineTooLarge }
                line.append(byte)
            }
        }
        return events
    }

    /// EOF never dispatches an incomplete event. Resume with a new parser seeded by the caller's cursor.
    mutating func finish() {
        line.removeAll(keepingCapacity: false)
        resetEvent()
        afterCR = false
    }

    private mutating func consumeLine() throws -> ServerSentEvent? {
        var text = String(decoding: line, as: UTF8.self)
        line.removeAll(keepingCapacity: true)
        if firstLine {
            firstLine = false
            if text.first == "\u{FEFF}" { text.removeFirst() }
        }
        if text.isEmpty {
            defer { resetEvent() }
            guard !dataLines.isEmpty else { return nil }
            return .init(id: lastEventID, event: eventName.isEmpty ? "message" : eventName,
                         data: dataLines.joined(separator: "\n"))
        }
        if text.hasPrefix(":") { return nil }
        let split = text.firstIndex(of: ":")
        let field = split.map { String(text[..<$0]) } ?? text
        var value = split.map { String(text[text.index(after: $0)...]) } ?? ""
        if value.hasPrefix(" ") { value.removeFirst() }
        switch field {
        case "data":
            let additional = value.utf8.count + 1
            guard additional <= maximumEventBytes - eventBytes else { throw ServerSentEventParseError.eventTooLarge }
            eventBytes += additional
            dataLines.append(value)
        case "event": eventName = value
        case "id": if !value.contains("\0") { lastEventID = value }
        case "retry":
            if !value.isEmpty && value.utf8.allSatisfy({ (48...57).contains($0) }), let retry = UInt64(value) {
                retryMilliseconds = retry
            }
        default: break
        }
        return nil
    }

    private mutating func resetEvent() {
        dataLines.removeAll(keepingCapacity: false)
        eventName = ""
        eventBytes = 0
    }
}
