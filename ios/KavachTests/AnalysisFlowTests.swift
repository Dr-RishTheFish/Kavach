import XCTest
@testable import Kavach

final class AnalysisFlowTests: XCTestCase {
    func testDraftNormalizesAndOmitsOptionalFields() throws {
        var draft = AnalysisDraft()
        draft.content = "  Synthetic example\n"
        draft.context = "  "
        draft.phoneNumber = " "
        XCTAssertEqual(try draft.request(), AnalysisRequest(kind: .call, content: "Synthetic example"))
        draft.phoneNumber = "+12025550123"
        draft.context = " Context "
        XCTAssertEqual(try draft.request().context, "Context")
        XCTAssertEqual(try draft.request().phoneNumber, "+12025550123")
        draft.kind = .url
        XCTAssertNil(try draft.request().phoneNumber)
    }

    func testValidationMatchesSchemaBoundaries() throws {
        var draft = AnalysisDraft()
        XCTAssertThrowsError(try draft.request())
        draft.content = String(repeating: "🙂", count: 5000)
        XCTAssertNoThrow(try draft.request())
        draft.content += "x"
        XCTAssertThrowsError(try draft.request())
        draft.content = String(repeating: "e\u{301}", count: 2501)
        XCTAssertThrowsError(try draft.request(), "JSON Schema counts Unicode code points, not grapheme clusters")
        draft.content = "Example"
        draft.context = String(repeating: "x", count: 1000)
        XCTAssertNoThrow(try draft.request())
        draft.context += "x"
        XCTAssertThrowsError(try draft.request())
        draft.context = ""
        for phone in ["555-0123", "+0123", "+1234567890123456", "+١٢٣"] {
            draft.phoneNumber = phone
            XCTAssertThrowsError(try draft.request())
        }
    }

    @MainActor
    func testNoAutomaticSubmissionAndInvalidInputNeverCallsService() async {
        let service = ControlledService()
        let model = AnalysisViewModel(serviceFactory: { _ in service })
        model.draft.content = " "
        await model.submit(configuration: .init())
        let count = await service.callCount()
        XCTAssertEqual(count, 0)
        guard case .failure = model.state else { return XCTFail("Expected validation failure") }
        model.draft.content = "New text"
        XCTAssertEqual(model.state, .idle)
        let countAfterEdit = await service.callCount()
        XCTAssertEqual(countAfterEdit, 0)
    }

    @MainActor
    func testDuplicateCancelStaleResultAndRetry() async throws {
        let service = ControlledService()
        let model = AnalysisViewModel(serviceFactory: { _ in service })
        model.draft.content = "First"
        let first = Task { await model.submit(configuration: .init()) }
        await service.waitForCalls(1)
        XCTAssertEqual(model.state, .loading)
        await model.submit(configuration: .init())
        let count = await service.callCount()
        XCTAssertEqual(count, 1)
        model.cancel()
        XCTAssertEqual(model.state, .idle)
        model.draft.content = "Second"
        let second = Task { await model.submit(configuration: .init()) }
        await service.waitForCalls(2)
        await service.complete(1, result: .success(try DemoScenario.lunch.assessment()))
        await second.value
        let current = model.state
        await service.complete(0, result: .success(try DemoScenario.bank.assessment()))
        await first.value
        XCTAssertEqual(model.state, current, "Late cancelled result must not overwrite current result")
        model.draft.content = "Third"
        let third = Task { await model.submit(configuration: .init()) }
        await service.waitForCalls(3)
        await service.complete(2, result: .failure(URLError(.timedOut)))
        await third.value
        guard case .failure(let error) = model.state else { return XCTFail("Expected failure") }
        XCTAssertTrue(error.message.contains("timed out"))
        XCTAssertTrue(model.canSubmit)
        let retry = Task { await model.submit(configuration: .init()) }
        await service.waitForCalls(4)
        await service.complete(3, result: .success(try DemoScenario.lunch.assessment()))
        await retry.value
        guard case .success = model.state else { return XCTFail("Retry should succeed") }
    }

    @MainActor
    func testEditingCancelsAndInvalidatesPendingResult() async throws {
        let service = ControlledService()
        let model = AnalysisViewModel(serviceFactory: { _ in service })
        model.draft.content = "Original"
        let submission = Task { await model.submit(configuration: .init()) }
        await service.waitForCalls(1)
        model.draft.kind = .url
        XCTAssertEqual(model.state, .idle)
        await service.complete(0, result: .success(try DemoScenario.bank.assessment()))
        await submission.value
        XCTAssertEqual(model.state, .idle)
    }

    @MainActor
    func testSettingsDefaultOfflineAndPersistOnlyConfiguration() throws {
        let name = "kavach-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.configuration, .init())
        settings.configuration = .init(mode: .live, baseURL: "https://example.test")
        XCTAssertEqual(AppSettings(defaults: defaults).configuration, settings.configuration)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: name)?.keys.map { $0 } ?? []),
                       Set(["analysisMode", "developmentAPIBaseURL"]))
    }

    @MainActor
    func testLiveWithoutAddressFailsWithoutMockFallback() async {
        let model = AnalysisViewModel()
        model.draft.content = "Synthetic example"
        await model.submit(configuration: .init(mode: .live, baseURL: ""))
        guard case .failure(let error) = model.state else { return XCTFail("Expected setup guidance") }
        XCTAssertTrue(error.message.contains("Settings"))
    }

    func testSourcePresentationAndSafeErrors() throws {
        XCTAssertEqual(AssessmentSource.mock.displayTitle, "DEMO · Simulated assessment")
        XCTAssertEqual(AssessmentSource.nvidia.displayTitle, "Analyzed with NVIDIA")
        let error = AnalysisDisplayError.from(AnalysisServiceError.api(503, .init(code: "ANALYZER_UNAVAILABLE", message: "SENSITIVE arbitrary content", requestId: "test")))
        XCTAssertFalse(error.message.contains("SENSITIVE"))
        XCTAssertTrue(error.message.contains("unavailable"))
    }
}

private actor ControlledService: AnalysisService {
    private var calls = 0
    private var pending: [Int: CheckedContinuation<RiskAssessment, Error>] = [:]
    func analyze(_ request: AnalysisRequest) async throws -> RiskAssessment {
        let index = calls
        calls += 1
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }
    func callCount() -> Int { calls }
    func waitForCalls(_ count: Int) async {
        while calls < count { await Task.yield() }
    }
    func complete(_ index: Int, result: Result<RiskAssessment, Error>) { pending.removeValue(forKey: index)?.resume(with: result) }
}
