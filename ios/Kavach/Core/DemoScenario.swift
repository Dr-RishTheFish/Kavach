import Foundation

enum DemoScenario: String, CaseIterable, Identifiable {
    case bank, code, delivery, unknownContact, lunch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bank: return "The urgent bank call"
        case .code: return "A request for your code"
        case .delivery: return "The unexpected delivery fee"
        case .unknownContact: return "An unfamiliar callback"
        case .lunch: return "Plans with a friend"
        }
    }
    var request: AnalysisRequest {
        switch self {
        case .bank: return .init(kind: .call, content: "I am from your bank, transfer money in ten minutes")
        case .code: return .init(kind: .sms, content: "Tell me the code we just texted you")
        case .delivery: return .init(kind: .url, content: "Delivery failed, pay a small fee at this link")
        case .unknownContact: return .init(kind: .call, content: "An unknown number asked me to call them back")
        case .lunch: return .init(kind: .message, content: "A friend confirmed our lunch plans")
        }
    }
    var score: Int {
        switch self {
        case .bank: return 92
        case .code: return 88
        case .delivery: return 64
        case .unknownContact: return 36
        case .lunch: return 12
        }
    }

    func assessment(kind: AnalysisKind? = nil, unrecognized: Bool = false) throws -> RiskAssessment {
        let summary: String
        let signals: [String]
        let actions: [String]
        switch self {
        case .bank:
            summary = "This description contains signs of a possible bank impersonation scam."
            signals = ["The caller claimed to represent a financial institution.", "The caller pressured the recipient to act immediately."]
            actions = ["Do not transfer money or share a one-time code.", "Contact your bank using a phone number you independently verify."]
        case .code:
            summary = "A request for a one-time code may put an account at risk."
            signals = ["The sender asked for a private verification code."]
            actions = ["Keep your code private.", "Check the account directly using its official app or website."]
        case .delivery:
            summary = "An unexpected delivery fee and link deserve a closer look."
            signals = ["The message asks for payment through an unsolicited link."]
            actions = ["Avoid the supplied link.", "Check delivery status through the carrier's official website."]
        case .unknownContact:
            summary = unrecognized ? "This text has no matching demo scenario. This simulated result cannot assess its safety." : "There is not enough context to assess this unfamiliar contact."
            signals = unrecognized ? [] : ["The contact was unexpected."]
            actions = ["Verify who contacted you through an independent channel.", "Keep personal information private while you check."]
        case .lunch:
            summary = "This sample describes ordinary plans with a friend. Low concern is not a safety guarantee."
            signals = []
            actions = ["If the conversation changes unexpectedly, confirm with your friend through a known contact method."]
        }
        return try RiskAssessment(analysisId: "demo-\(rawValue)", kind: kind ?? request.kind,
                                  riskScore: score, summary: summary, signals: signals,
                                  recommendedActions: actions, source: .mock,
                                  requiresHumanReview: self == .unknownContact,
                                  analyzedAt: Date(timeIntervalSince1970: 1_794_124_800))
    }
}
