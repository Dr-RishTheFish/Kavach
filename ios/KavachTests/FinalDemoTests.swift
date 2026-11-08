import XCTest
@testable import Kavach

@MainActor
final class FinalDemoTests: XCTestCase {
    func testPrivateReportsAndExplicitConsent() throws {
        let store = FinalDemoStore()
        store.enterDemoAccount(.asha)
        let assessment = try DemoScenario.bank.assessment()
        XCTAssertThrowsError(try store.save(assessment: assessment, description: "", notes: "", consent: false, operation: UUID()))
        let report = try store.save(assessment: assessment, description: "", notes: "note", consent: true, operation: UUID())
        XCTAssertNil(report.description)
        XCTAssertEqual(store.reports.count, 1)
        store.signOut()
        XCTAssertTrue(store.reports.isEmpty)
        store.enterDemoAccount(.ravi)
        XCTAssertTrue(store.reports.isEmpty)
        XCTAssertThrowsError(try store.deleteReport(report.id))
    }

    func testSharingRequiresConsentAndIsIdempotent() throws {
        let store = FinalDemoStore()
        store.enterDemoAccount(.asha)
        let report = try store.save(assessment: DemoScenario.bank.assessment(), description: "private", notes: "", consent: true, operation: UUID())
        let circle = try store.createCircle(name: "Demo circle")
        let operation = UUID()
        XCTAssertThrowsError(try store.share(report: report.id, circle: circle.id, preview: "Check codes", consent: false, operation: operation))
        try store.share(report: report.id, circle: circle.id, preview: "Check codes", consent: true, operation: operation)
        try store.share(report: report.id, circle: circle.id, preview: "Check codes", consent: true, operation: operation)
        XCTAssertEqual(store.alerts(in: circle.id).count, 1)
        XCTAssertEqual(store.alerts(in: circle.id).first?.preview, "Check codes")
        XCTAssertThrowsError(try store.share(report: report.id, circle: circle.id, preview: "Changed", consent: true, operation: operation))
    }

    func testInviteExpiryRedemptionAndMembershipIsolation() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let store = FinalDemoStore()
        store.enterDemoAccount(.asha)
        let circle = try store.createCircle(name: "Family")
        let invite = try store.invite(to: circle.id, now: now)
        store.enterDemoAccount(.ravi)
        XCTAssertTrue(store.circles.isEmpty)
        XCTAssertThrowsError(try store.join(code: invite.code, now: now.addingTimeInterval(901)))
        try store.join(code: invite.code, now: now)
        XCTAssertEqual(store.circles.count, 1)
        XCTAssertThrowsError(try store.join(code: invite.code, now: now))
        try store.leave(circle.id)
        XCTAssertTrue(store.circles.isEmpty)
        XCTAssertTrue(store.alerts(in: circle.id).isEmpty)
    }

    func testSharedPreviewDoesNotGrantPrivateReportAccessAndRemovalRevokesFeed() throws {
        let store = FinalDemoStore()
        store.enterDemoAccount(.asha)
        let report = try store.save(assessment: DemoScenario.bank.assessment(), description: "Fictional private original", notes: "Fictional private note", consent: true, operation: UUID())
        let circle = try store.createCircle(name: "Trusted demo")
        let invite = try store.invite(to: circle.id)
        try store.share(report: report.id, circle: circle.id, preview: "Possible bank impersonation", consent: true, operation: UUID())
        store.enterDemoAccount(.ravi)
        try store.join(code: invite.code)
        XCTAssertTrue(store.reports.isEmpty)
        XCTAssertEqual(store.alerts(in: circle.id).first?.preview, "Possible bank impersonation")
        XCTAssertThrowsError(try store.deleteReport(report.id))
        store.enterDemoAccount(.asha)
        try store.remove(.ravi, from: circle.id)
        store.enterDemoAccount(.ravi)
        XCTAssertTrue(store.circles.isEmpty)
        XCTAssertTrue(store.alerts(in: circle.id).isEmpty)
    }
}
