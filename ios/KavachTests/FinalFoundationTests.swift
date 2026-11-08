import XCTest
@testable import Kavach

final class FinalFoundationTests: XCTestCase {
    func testNonceUsesSecureRandomnessAndKnownSHA256() throws {
        XCTAssertEqual(AppleSignInNonce.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let first = try AppleSignInNonce.generate()
        let second = try AppleSignInNonce.generate()
        XCTAssertEqual(first.rawValue.count, 64)
        XCTAssertNotEqual(first.rawValue, second.rawValue)
        XCTAssertEqual(first.sha256Value, AppleSignInNonce.sha256(first.rawValue))
    }

    func testSSEParsesByteFragmentsUnicodeMultilineAndCRLF() throws {
        var parser = ServerSentEventParser()
        let input = Data(": heartbeat\r\nid: 42\r\nevent: alert\r\ndata: café 🙂\r\ndata: second\r\n\r\n".utf8)
        var events: [ServerSentEvent] = []
        for byte in input { events += try parser.append(Data([byte])) }
        XCTAssertEqual(events, [.init(id: "42", event: "alert", data: "café 🙂\nsecond")])
        XCTAssertEqual(parser.lastEventID, "42")
    }

    func testSSEPersistsAndResetsIDAndIgnoresInvalidRetry() throws {
        var parser = ServerSentEventParser()
        let events = try parser.append(Data("id: a\nretry: 2000\n\ndata: one\n\nid:\ndata: two\n\nretry: -1\nretry: 1x\nid: bad\0id\n\n".utf8))
        XCTAssertEqual(events.map(\.id), ["a", ""])
        XCTAssertEqual(parser.lastEventID, "")
        XCTAssertEqual(parser.retryMilliseconds, 2000)
    }

    func testSSESupportsBOMBareCRAndEmptyData() throws {
        var parser = ServerSentEventParser()
        let events = try parser.append(Data("\u{FEFF}event:\rdata:\r\r".utf8))
        XCTAssertEqual(events, [.init(id: "", event: "message", data: "")])
    }

    func testSSEBoundsLineAndEventAndDiscardsIncompleteFrame() throws {
        var lineParser = ServerSentEventParser(maximumLineBytes: 8, maximumEventBytes: 20)
        XCTAssertThrowsError(try lineParser.append(Data("data: 123".utf8)))
        var eventParser = ServerSentEventParser(maximumLineBytes: 20, maximumEventBytes: 8)
        XCTAssertThrowsError(try eventParser.append(Data("data: 1234\ndata: 5678\n".utf8)))
        var partial = ServerSentEventParser()
        XCTAssertTrue(try partial.append(Data("data: incomplete\n".utf8)).isEmpty)
        partial.finish()
        XCTAssertTrue(try partial.append(Data("\n".utf8)).isEmpty)
    }
}
