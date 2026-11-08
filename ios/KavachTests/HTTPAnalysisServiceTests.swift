import XCTest
@testable import Kavach

final class HTTPAnalysisServiceTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSuccessSendsContractRequest() async throws {
        let responseData = try fixtureData()
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.invalid/api/v1/analyze")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.timeoutInterval, 7)
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            let sent = try APIJSON.decoder().decode(AnalysisRequest.self, from: data)
            XCTAssertEqual(sent, AnalysisRequest(kind: .call, content: "Synthetic request", phoneNumber: "+12025550123", context: "Test context"))
            return (200, responseData)
        }
        let service = try HTTPAnalysisService(baseURL: URL(string: "https://example.invalid")!, session: session, timeout: 7)
        let result = try await service.analyze(.init(kind: .call, content: "Synthetic request", phoneNumber: "+12025550123", context: "Test context"))
        XCTAssertEqual(result.riskScore, 92)
        XCTAssertEqual(result.source, .mock)
    }

    func testAPIErrorPreservesStatusCodeMessageAndRequestID() async throws {
        StubURLProtocol.handler = { _ in
            (400, Data(#"{"error":{"code":"VALIDATION_ERROR","message":"Please provide content.","requestId":"fixture-request"}}"#.utf8))
        }
        do {
            _ = try await client().analyze(.init(kind: .call, content: ""))
            XCTFail("Expected an API error")
        } catch AnalysisServiceError.api(let status, let detail) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(detail.code, "VALIDATION_ERROR")
            XCTAssertEqual(detail.message, "Please provide content.")
            XCTAssertEqual(detail.requestId, "fixture-request")
        }
    }

    func testNonJSONFailureDoesNotBecomeMockSuccess() async throws {
        StubURLProtocol.handler = { _ in (502, Data("Bad gateway".utf8)) }
        do {
            _ = try await client().analyze(.init(kind: .call, content: "Synthetic request"))
            XCTFail("Expected HTTP failure")
        } catch AnalysisServiceError.httpStatus(let status) { XCTAssertEqual(status, 502) }
    }

    func testMalformedSuccessIsRejected() async throws {
        StubURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
        do {
            _ = try await client().analyze(.init(kind: .call, content: "Synthetic request"))
            XCTFail("Expected a decoding failure")
        } catch is DecodingError { }
    }

    func testTimeoutPropagates() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        do {
            _ = try await client().analyze(.init(kind: .call, content: "Synthetic request"))
            XCTFail("Expected timeout")
        } catch let error as URLError { XCTAssertEqual(error.code, .timedOut) }
    }

    func testCancellationBeforeRequest() async throws {
        let service = try client()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.analyze(.init(kind: .call, content: "Synthetic request"))
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
    }

    func testRejectsInvalidDevelopmentURLs() {
        for string in ["file:///tmp/input", "https://user:password@example.invalid", "https://example.invalid?key=value", "https://example.invalid#fragment"] {
            XCTAssertThrowsError(try HTTPAnalysisService(baseURL: URL(string: string)!))
        }
    }

    private func client() throws -> HTTPAnalysisService {
        try HTTPAnalysisService(baseURL: URL(string: "https://example.invalid")!, session: session)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    // Tests run serially; each test owns its ephemeral session and resets this handler.
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
