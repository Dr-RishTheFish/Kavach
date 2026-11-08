import Foundation
import Combine

// Presentation domain only. These types are deliberately not backend wire DTOs.
enum DemoAccount: String, CaseIterable, Identifiable {
    case asha = "Asha", ravi = "Ravi"
    var id: String { rawValue }
}

struct DemoReport: Identifiable, Equatable {
    let id: UUID
    let owner: DemoAccount
    let assessment: RiskAssessment
    let description: String?
    let notes: String?
    let createdAt: Date
}

struct DemoCircle: Identifiable, Equatable {
    let id: UUID
    let name: String
    let owner: DemoAccount
    var members: Set<DemoAccount>
}

struct DemoInvite: Identifiable {
    let id: UUID
    let circleID: UUID
    let code: String
    let expiresAt: Date
}

struct DemoAlert: Identifiable, Equatable {
    let id: UUID
    let circleID: UUID
    let reportID: UUID
    let preview: String
    let level: RiskLevel
    let createdAt: Date
}

enum FinalDemoError: LocalizedError {
    case signedOut, consentRequired, unavailable, invalidInput, invalidInvite, ownerMustRemoveCircle, conflict
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Choose a fictional demo account first."
        case .consentRequired: return "Please confirm this separate action before continuing."
        case .unavailable: return "This item is not available to the current demo account."
        case .invalidInput: return "Check the text length and required fields."
        case .invalidInvite: return "This demo invitation is expired, used, or invalid."
        case .ownerMustRemoveCircle: return "The owner must keep the circle while other members remain. Remove members first."
        case .conflict: return "This retry no longer matches the original action. Start a new action."
        }
    }
}

@MainActor
protocol FinalWorkspaceService: AnyObject {
    var account: DemoAccount? { get }
    var reports: [DemoReport] { get }
    var circles: [DemoCircle] { get }
    func enterDemoAccount(_ account: DemoAccount)
    func signOut()
    func save(assessment: RiskAssessment, description: String, notes: String, consent: Bool, operation: UUID) throws -> DemoReport
    func deleteReport(_ id: UUID) throws
    func createCircle(name: String) throws -> DemoCircle
    func invite(to circleID: UUID, now: Date) throws -> DemoInvite
    func join(code: String, now: Date) throws
    func leave(_ circleID: UUID) throws
    func share(report: UUID, circle: UUID, preview: String, consent: Bool, operation: UUID) throws
    func alerts(in circleID: UUID) -> [DemoAlert]
}

/// Explicitly selected, in-memory demonstration. No network, credentials, or durable storage.
@MainActor
final class FinalDemoStore: ObservableObject, FinalWorkspaceService {
    @Published private(set) var account: DemoAccount?
    @Published private var allReports: [DemoReport] = []
    @Published private var allCircles: [DemoCircle] = []
    @Published private var allAlerts: [DemoAlert] = []
    private var invites: [String: DemoInvite] = [:]
    private struct SaveAction: Equatable { let account: DemoAccount; let assessment: RiskAssessment; let description: String; let notes: String }
    private struct ShareAction: Equatable { let account: DemoAccount; let report: UUID; let circle: UUID; let preview: String }
    private var savedActions: [UUID: (SaveAction, DemoReport)] = [:]
    private var sharedActions: [UUID: ShareAction] = [:]

    var reports: [DemoReport] { allReports.filter { $0.owner == account }.sorted { $0.createdAt > $1.createdAt } }
    var circles: [DemoCircle] { guard let account else { return [] }; return allCircles.filter { $0.members.contains(account) } }

    func enterDemoAccount(_ account: DemoAccount) { self.account = account }
    func signOut() { account = nil }
    func clearDemoData() {
        signOut(); allReports = []; allCircles = []; allAlerts = []; invites = [:]; savedActions = [:]; sharedActions = [:]
    }

    func save(assessment: RiskAssessment, description: String, notes: String, consent: Bool, operation: UUID) throws -> DemoReport {
        guard let account else { throw FinalDemoError.signedOut }
        guard consent else { throw FinalDemoError.consentRequired }
        guard description.unicodeScalars.count <= 5000, notes.unicodeScalars.count <= 1000 else { throw FinalDemoError.invalidInput }
        let action = SaveAction(account: account, assessment: assessment, description: description, notes: notes)
        if let (previous, report) = savedActions[operation] {
            guard previous == action else { throw FinalDemoError.conflict }; return report
        }
        let report = DemoReport(id: UUID(), owner: account, assessment: assessment,
                                description: optional(description), notes: optional(notes), createdAt: Date())
        allReports.append(report); savedActions[operation] = (action, report)
        return report
    }

    func deleteReport(_ id: UUID) throws {
        guard reports.contains(where: { $0.id == id }) else { throw FinalDemoError.unavailable }
        allReports.removeAll { $0.id == id }
        allAlerts.removeAll { $0.reportID == id }
    }

    func createCircle(name: String) throws -> DemoCircle {
        guard let account else { throw FinalDemoError.signedOut }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw FinalDemoError.invalidInput }
        let circle = DemoCircle(id: UUID(), name: name, owner: account, members: [account])
        allCircles.append(circle); return circle
    }

    func invite(to circleID: UUID, now: Date = Date()) throws -> DemoInvite {
        guard let circle = circles.first(where: { $0.id == circleID }), circle.owner == account else { throw FinalDemoError.unavailable }
        let invite = DemoInvite(id: UUID(), circleID: circleID, code: "DEMO-" + UUID().uuidString.prefix(8), expiresAt: now.addingTimeInterval(900))
        invites[invite.code] = invite; return invite
    }

    func join(code: String, now: Date = Date()) throws {
        guard let account else { throw FinalDemoError.signedOut }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let invite = invites[code], invite.expiresAt > now,
              let index = allCircles.firstIndex(where: { $0.id == invite.circleID }),
              !allCircles[index].members.contains(account) else { throw FinalDemoError.invalidInvite }
        allCircles[index].members.insert(account); invites.removeValue(forKey: code)
    }

    func leave(_ circleID: UUID) throws {
        guard let account, let index = allCircles.firstIndex(where: { $0.id == circleID && $0.members.contains(account) }) else { throw FinalDemoError.unavailable }
        if allCircles[index].owner == account {
            guard allCircles[index].members.count == 1 else { throw FinalDemoError.ownerMustRemoveCircle }
            allCircles.remove(at: index); allAlerts.removeAll { $0.circleID == circleID }
        } else { allCircles[index].members.remove(account) }
    }

    func remove(_ member: DemoAccount, from circleID: UUID) throws {
        guard let index = allCircles.firstIndex(where: { $0.id == circleID }), allCircles[index].owner == account,
              member != account else { throw FinalDemoError.unavailable }
        allCircles[index].members.remove(member)
    }

    func share(report: UUID, circle: UUID, preview: String, consent: Bool, operation: UUID) throws {
        guard let account else { throw FinalDemoError.signedOut }
        guard consent else { throw FinalDemoError.consentRequired }
        guard let ownReport = reports.first(where: { $0.id == report }), circles.contains(where: { $0.id == circle }) else { throw FinalDemoError.unavailable }
        let preview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preview.isEmpty, preview.unicodeScalars.count <= 140 else { throw FinalDemoError.invalidInput }
        let action = ShareAction(account: account, report: report, circle: circle, preview: preview)
        if let previous = sharedActions[operation] { guard previous == action else { throw FinalDemoError.conflict }; return }
        allAlerts.append(.init(id: UUID(), circleID: circle, reportID: report, preview: preview, level: ownReport.assessment.riskLevel, createdAt: Date()))
        sharedActions[operation] = action
    }

    func alerts(in circleID: UUID) -> [DemoAlert] {
        guard circles.contains(where: { $0.id == circleID }) else { return [] }
        return allAlerts.filter { $0.circleID == circleID }.sorted { $0.createdAt > $1.createdAt }
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
