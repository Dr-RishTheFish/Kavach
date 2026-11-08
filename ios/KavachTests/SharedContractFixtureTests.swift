import XCTest
@testable import Kavach

/// L3: Swift must decode Person 2's canonical fixtures in shared/contracts/ directly, without
/// adapting fields, and the iOS fixture copy must not drift from them.
/// Runs under `swift test` (SwiftPM); reads files relative to this source file.
final class SharedContractFixtureTests: XCTestCase {
    static let contractsDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // KavachTests
        .deletingLastPathComponent()      // ios
        .deletingLastPathComponent()      // repo root
        .appendingPathComponent("shared/contracts/examples")

    private func example(_ name: String) throws -> Data {
        let url = Self.contractsDir.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("shared/contracts not present at \(url.path)")
        }
        return try Data(contentsOf: url)
    }

    func testIOSFixtureMatchesCanonicalFixture() throws {
        let canonical = try JSONSerialization.jsonObject(with: example("analyze-response.json")) as? NSDictionary
        let iosCopy = try JSONSerialization.jsonObject(with: fixtureData()) as? NSDictionary
        XCTAssertNotNil(canonical)
        XCTAssertEqual(canonical, iosCopy, "ios/KavachTests/Fixtures/assessment.json drifted from shared/contracts")
    }

    func testDecodesCanonicalResponse() throws {
        let value = try APIJSON.decoder().decode(RiskAssessment.self, from: example("analyze-response.json"))
        XCTAssertEqual(value.riskLevel, try RiskLevel.forScore(value.riskScore))
        XCTAssertEqual(value.source, .mock)
        XCTAssertNotNil(UUID(uuidString: value.analysisId))
    }

    func testDecodesCanonicalErrorEnvelope() throws {
        let value = try APIJSON.decoder().decode(APIErrorEnvelope.self, from: example("analyze-error.json"))
        XCTAssertEqual(value.error.code, "VALIDATION_ERROR")
        XCTAssertFalse(value.error.requestId.isEmpty)
    }

    func testDecodesAndReencodesCanonicalRequest() throws {
        let data = try example("analyze-request.json")
        let request = try APIJSON.decoder().decode(AnalysisRequest.self, from: data)
        XCTAssertEqual(request.kind, .call)
        let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
        let reencoded = try JSONSerialization.jsonObject(with: APIJSON.encoder().encode(request)) as? NSDictionary
        XCTAssertEqual(original, reencoded, "Swift request encoding must produce exactly the canonical wire keys")
    }
}
