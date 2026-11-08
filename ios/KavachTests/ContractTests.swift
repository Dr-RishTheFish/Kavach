import XCTest
@testable import Kavach

final class ContractTests: XCTestCase {
    func testRiskBoundaries() throws {
        let cases: [(Int, RiskLevel)] = [(0, .low), (24, .low), (25, .guarded), (49, .guarded),
                                        (50, .high), (74, .high), (75, .critical), (100, .critical)]
        for (score, expected) in cases { XCTAssertEqual(try RiskLevel.forScore(score), expected) }
        XCTAssertThrowsError(try RiskLevel.forScore(-1))
        XCTAssertThrowsError(try RiskLevel.forScore(101))
    }

    func testCanonicalFixtureAndRoundTrip() throws {
        let value = try APIJSON.decoder().decode(RiskAssessment.self, from: fixtureData())
        XCTAssertEqual(value.analysisId, "00000000-0000-4000-8000-000000000001")
        XCTAssertEqual(value.kind, .call)
        XCTAssertEqual(value.riskScore, 92)
        XCTAssertEqual(value.riskLevel, .critical)
        XCTAssertEqual(value.source, .mock)
        XCTAssertFalse(value.requiresHumanReview)
        XCTAssertEqual(value.signals.count, 2)
        XCTAssertEqual(value.recommendedActions.count, 2)
        let encoded = try APIJSON.encoder().encode(value)
        XCTAssertEqual(try APIJSON.decoder().decode(RiskAssessment.self, from: encoded), value)
        let noFraction = String(decoding: try fixtureData(), as: UTF8.self)
            .replacingOccurrences(of: ".000Z", with: "Z")
        XCTAssertEqual(try APIJSON.decoder().decode(RiskAssessment.self, from: Data(noFraction.utf8)), value)
    }

    func testInvalidAssessmentIsRejected() throws {
        let json = String(decoding: try fixtureData(), as: UTF8.self)
        for invalid in [json.replacingOccurrences(of: "92", with: "101"),
                        json.replacingOccurrences(of: "\"critical\"", with: "\"low\"")] {
            XCTAssertThrowsError(try APIJSON.decoder().decode(RiskAssessment.self, from: Data(invalid.utf8)))
        }
    }

    func testRequestWireKeysAndOptionalFields() throws {
        let request = AnalysisRequest(kind: .call, content: "Synthetic example", phoneNumber: "+12025550123", context: "Not initiated by me")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSON.encoder().encode(request)) as? [String: String])
        XCTAssertEqual(json, ["kind": "call", "content": "Synthetic example", "phoneNumber": "+12025550123", "context": "Not initiated by me"])
        let minimal = AnalysisRequest(kind: .url, content: "https://example.com")
        let minimalJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: APIJSON.encoder().encode(minimal)) as? [String: String])
        XCTAssertEqual(Set(minimalJSON.keys), Set(["kind", "content"]))
    }

    func testAllMockScenariosAndUnknownInput() async throws {
        var levels = Set<RiskLevel>()
        for scenario in DemoScenario.allCases {
            let result = try await MockAnalysisService().analyze(scenario.request)
            XCTAssertEqual(result.source, .mock)
            XCTAssertEqual(result.kind, scenario.request.kind)
            XCTAssertEqual(result.riskLevel, try RiskLevel.forScore(result.riskScore))
            levels.insert(result.riskLevel)
        }
        XCTAssertEqual(levels, Set(RiskLevel.allCases))
        let unknown = try await MockAnalysisService().analyze(.init(kind: .message, content: "Unrecognized synthetic text"))
        XCTAssertEqual(unknown.riskLevel, .guarded)
        XCTAssertTrue(unknown.requiresHumanReview)
    }
}

func fixtureData() throws -> Data {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: ContractTests.self)
    #endif
    let url = try XCTUnwrap(bundle.url(forResource: "assessment", withExtension: "json"))
    return try Data(contentsOf: url)
}
