import XCTest
@testable import Kavach

/// L4: real HTTPAnalysisService -> real kavach backend (mock analyzer) -> Swift models.
/// Skipped unless KAVACH_LIVE_API_URL is set, e.g. KAVACH_LIVE_API_URL=http://127.0.0.1:3101
/// Uses fictional data only (555 numbers, synthetic text).
final class LiveBackendIntegrationTests: XCTestCase {
    private var service: HTTPAnalysisService!
    private var baseURL: URL!

    override func setUpWithError() throws {
        guard let raw = ProcessInfo.processInfo.environment["KAVACH_LIVE_API_URL"], let url = URL(string: raw) else {
            throw XCTSkip("Set KAVACH_LIVE_API_URL to run live backend integration tests")
        }
        baseURL = url
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        service = try HTTPAnalysisService(baseURL: url, session: URLSession(configuration: config), timeout: 5)
    }

    private func expectAPIError(_ request: AnalysisRequest, status: Int, code: String,
                                file: StaticString = #filePath, line: UInt = #line) async -> APIErrorEnvelope.Detail? {
        do {
            _ = try await service.analyze(request)
            XCTFail("expected HTTP \(status) \(code)", file: file, line: line)
        } catch AnalysisServiceError.api(let gotStatus, let detail) {
            XCTAssertEqual(gotStatus, status, file: file, line: line)
            XCTAssertEqual(detail.code, code, file: file, line: line)
            XCTAssertFalse(detail.requestId.isEmpty, file: file, line: line)
            return detail
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
        return nil
    }

    // P1-P5, C1, C6, C7, C8
    func testLiveScenariosMatchIOSMockLevels() async throws {
        for scenario in DemoScenario.allCases {
            let live = try await service.analyze(scenario.request)
            let local = try await MockAnalysisService().analyze(scenario.request)
            XCTAssertEqual(live.riskLevel, local.riskLevel, "level drift for \(scenario.rawValue)")
            XCTAssertEqual(live.source, .mock, "Module 0 backend must label results as mock")
            XCTAssertEqual(live.kind, scenario.request.kind)
            XCTAssertNotNil(UUID(uuidString: live.analysisId), "server analysisId must be a UUID")
            XCTAssertLessThan(abs(live.analyzedAt.timeIntervalSinceNow), 300, "analyzedAt should be current")
            XCTAssertFalse(live.summary.isEmpty)
            XCTAssertFalse(live.recommendedActions.isEmpty)
        }
    }

    // P6
    func testUnrecognizedTextIsGuardedAndFlaggedOnBothSides() async throws {
        let request = AnalysisRequest(kind: .message, content: "Unrecognized synthetic text about the weather")
        let live = try await service.analyze(request)
        let local = try await MockAnalysisService().analyze(request)
        XCTAssertEqual(live.riskLevel, .guarded)
        XCTAssertEqual(live.riskLevel, local.riskLevel)
        XCTAssertTrue(live.requiresHumanReview)
        XCTAssertTrue(local.requiresHumanReview)
    }

    // C5, C7
    func testFullAndMinimalRequestsAreAccepted() async throws {
        let full = AnalysisRequest(kind: .call, content: "A caller claimed to be my bank and urgently requested a transfer.",
                                   phoneNumber: "+12025550123", context: "I did not initiate the call.")
        let a = try await service.analyze(full)
        let b = try await service.analyze(AnalysisRequest(kind: .url, content: "Delivery failed, pay a small fee at this link"))
        XCTAssertEqual(a.riskLevel, .critical)
        XCTAssertEqual(b.riskLevel, .high)
        XCTAssertNotEqual(a.analysisId, b.analysisId)
    }

    // E1
    func testBlankContentMapsToValidationError() async throws {
        let detail = await expectAPIError(.init(kind: .sms, content: "   "), status: 400, code: "VALIDATION_ERROR")
        XCTAssertFalse(detail?.message.isEmpty ?? true)
    }

    // E2
    func testInvalidPhoneMapsToValidationError() async throws {
        let detail = await expectAPIError(.init(kind: .call, content: "MARKER-PHONE-TEST", phoneNumber: "555-0123"),
                                          status: 400, code: "VALIDATION_ERROR")
        XCTAssertFalse(detail?.message.contains("MARKER") ?? true, "error messages must not echo user input")
        XCTAssertFalse(detail?.message.contains("555-0123") ?? true)
    }

    // E3
    func testContentLengthBoundary() async throws {
        _ = try await service.analyze(.init(kind: .sms, content: String(repeating: "a", count: 5000)))
        _ = await expectAPIError(.init(kind: .sms, content: String(repeating: "a", count: 5001)),
                                 status: 400, code: "VALIDATION_ERROR")
    }

    // E4
    func testOversizedBodyMapsToPayloadTooLarge() async throws {
        _ = await expectAPIError(.init(kind: .sms, content: String(repeating: "a", count: 40_000)),
                                 status: 413, code: "PAYLOAD_TOO_LARGE")
    }

    // S6
    func testUnicodeContentRoundTrips() async throws {
        let live = try await service.analyze(.init(kind: .message, content: "मेरे दोस्त ने lunch plans confirm किए 🙂"))
        XCTAssertEqual(live.riskLevel, .low)
        _ = try await service.analyze(.init(kind: .sms, content: String(repeating: "🙂", count: 5000)))
    }

    func testTrailingSlashBaseURLWorks() async throws {
        let slashed = try HTTPAnalysisService(baseURL: baseURL.appendingPathComponent(""), timeout: 5)
        let result = try await slashed.analyze(.init(kind: .call, content: "Tell me the code we just texted you"))
        XCTAssertEqual(result.riskLevel, .critical)
    }

    // E5
    func testUnreachableServerThrowsInsteadOfFallingBack() async throws {
        let dead = try HTTPAnalysisService(baseURL: URL(string: "http://127.0.0.1:1")!, timeout: 3)
        do {
            _ = try await dead.analyze(.init(kind: .call, content: "I am from your bank, transfer money in ten minutes"))
            XCTFail("an unreachable server must not produce an assessment")
        } catch is URLError {
            // expected: the error surfaces, no mock result is substituted
        }
    }
}
