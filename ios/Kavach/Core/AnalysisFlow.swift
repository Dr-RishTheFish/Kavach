import Foundation
import Combine

enum AnalysisMode: String, CaseIterable, Sendable {
    case mock, live
    var title: String { self == .mock ? "Mock (offline)" : "Live backend" }
}

struct AnalysisConfiguration: Equatable, Sendable {
    var mode: AnalysisMode = .mock
    var baseURL = ""

    func service() throws -> any AnalysisService {
        if mode == .mock { return MockAnalysisService() }
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisDisplayError(message: "Add your backend address in Settings before using Live backend.")
        }
        guard let url = URL(string: baseURL) else { throw AnalysisServiceError.invalidBaseURL }
        return try HTTPAnalysisService(baseURL: url)
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var configuration: AnalysisConfiguration {
        didSet {
            defaults.set(configuration.mode.rawValue, forKey: "analysisMode")
            defaults.set(configuration.baseURL, forKey: "developmentAPIBaseURL")
        }
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configuration = .init(mode: AnalysisMode(rawValue: defaults.string(forKey: "analysisMode") ?? "") ?? .mock,
                              baseURL: defaults.string(forKey: "developmentAPIBaseURL") ?? "")
    }
}

struct AnalysisDraft: Equatable {
    var kind: AnalysisKind = .call
    var content = ""
    var phoneNumber = ""
    var context = ""
    var supportsPhone: Bool { kind == .call || kind == .sms }
    // JSON Schema maxLength counts Unicode code points, not Swift grapheme clusters.
    var contentCount: Int { content.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count }
    var contextCount: Int { context.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count }

    func request() throws -> AnalysisRequest {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...5000).contains(contentCount) else {
            throw AnalysisDisplayError(message: "Enter between 1 and 5,000 characters of content.")
        }
        guard contextCount <= 1000 else {
            throw AnalysisDisplayError(message: "Keep additional context within 1,000 characters.")
        }
        if supportsPhone && !phone.isEmpty && phone.range(of: #"^\+[1-9][0-9]{0,14}$"#, options: .regularExpression) == nil {
            throw AnalysisDisplayError(message: "Use an international phone number: + followed by up to 15 digits, with no spaces or leading zero.")
        }
        return .init(kind: kind, content: text, phoneNumber: supportsPhone && !phone.isEmpty ? phone : nil,
                     context: note.isEmpty ? nil : note)
    }
    var validationMessage: String? {
        do { _ = try request(); return nil }
        catch { return AnalysisDisplayError.from(error).message }
    }
}

struct AnalysisDisplayError: Error, Equatable {
    let message: String
    static func from(_ error: Error) -> Self {
        if let value = error as? Self { return value }
        if let value = error as? URLError {
            switch value.code {
            case .timedOut: return .init(message: "The request timed out. Check the server and try again.")
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return .init(message: "Cannot reach the analysis server. Check the address, Wi-Fi and server startup, then retry.")
            case .appTransportSecurityRequiresSecureConnection:
                return .init(message: "This connection requires HTTPS or a narrow development-only local-network exception. See the iOS setup guide.")
            default: return .init(message: "The network request failed. Check your connection and try again.")
            }
        }
        if let value = error as? AnalysisServiceError {
            switch value {
            case .invalidBaseURL: return .init(message: "Set a valid HTTP or HTTPS backend address in Settings, without credentials, query or fragment.")
            case .api(_, let detail):
                switch detail.code {
                case "VALIDATION_ERROR", "INVALID_JSON": return .init(message: "The server could not accept this input. Check the fields and try again.")
                case "PAYLOAD_TOO_LARGE": return .init(message: "The request is too large. Shorten the content or context and retry.")
                case "ANALYZER_UNAVAILABLE": return .init(message: "Analysis is temporarily unavailable. Try again later; no assessment was generated.")
                default: return .init(message: "The server could not complete the analysis. Try again later.")
                }
            case .httpStatus: return .init(message: "The server returned an error. Check its configuration and try again.")
            case .invalidResponse: break
            }
        }
        return .init(message: "The server returned an invalid assessment. No result is shown. Try again or contact the backend owner.")
    }
}

enum AnalysisState: Equatable {
    case idle, validating, loading, success(RiskAssessment), failure(AnalysisDisplayError)
}

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published var draft = AnalysisDraft() { didSet { if draft != oldValue { cancel() } } }
    @Published private(set) var state: AnalysisState = .idle
    @Published private(set) var submittedMode: AnalysisMode = .mock
    private var generation = UUID()
    private var requestTask: Task<RiskAssessment, Error>?
    private let serviceFactory: (AnalysisConfiguration) throws -> any AnalysisService

    init(serviceFactory: @escaping (AnalysisConfiguration) throws -> any AnalysisService = { try $0.service() }) {
        self.serviceFactory = serviceFactory
    }
    var isBusy: Bool { state == .loading || state == .validating }
    var canSubmit: Bool { !isBusy && draft.validationMessage == nil }

    func cancel() {
        generation = UUID()
        requestTask?.cancel()
        requestTask = nil
        state = .idle
    }

    func submit(configuration: AnalysisConfiguration) async {
        guard !isBusy else { return }
        let token = UUID()
        generation = token
        state = .validating
        do {
            let request = try draft.request()
            let service = try serviceFactory(configuration)
            submittedMode = configuration.mode
            state = .loading
            let task = Task { try await service.analyze(request) }
            requestTask = task
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard generation == token else { return }
            try Task.checkCancellation()
            state = .success(result)
        } catch {
            guard generation == token else { return }
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                state = .idle
            } else { state = .failure(.from(error)) }
        }
        if generation == token { requestTask = nil }
    }
}

extension AssessmentSource {
    var displayTitle: String { self == .mock ? "DEMO · Simulated assessment" : "Analyzed with NVIDIA" }
}
