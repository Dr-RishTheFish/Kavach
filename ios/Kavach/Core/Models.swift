import Foundation

enum AnalysisKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case call, sms, message, url
    var id: String { rawValue }
    var title: String {
        switch self {
        case .call: return "Call"
        case .sms: return "Text/SMS"
        case .message: return "Message"
        case .url: return "URL"
        }
    }
    var symbol: String {
        switch self {
        case .call: return "phone"
        case .sms: return "text.bubble"
        case .message: return "bubble.left.and.bubble.right"
        case .url: return "link"
        }
    }
}

struct AnalysisRequest: Codable, Equatable, Sendable {
    let kind: AnalysisKind
    let content: String
    var phoneNumber: String? = nil
    var context: String? = nil
}

enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low, guarded, high, critical

    static func forScore(_ score: Int) throws -> Self {
        switch score {
        case 0...24: return .low
        case 25...49: return .guarded
        case 50...74: return .high
        case 75...100: return .critical
        default: throw AssessmentValidationError.invalidScore
        }
    }
    var title: String { rawValue.capitalized }
}

enum AssessmentSource: String, Codable, Sendable { case mock, nvidia }
enum AssessmentValidationError: Error { case invalidScore, mismatchedLevel }

struct RiskAssessment: Codable, Equatable, Identifiable, Sendable {
    let analysisId: String
    let kind: AnalysisKind
    let riskScore: Int
    let riskLevel: RiskLevel
    let summary: String
    let signals: [String]
    let recommendedActions: [String]
    let source: AssessmentSource
    let requiresHumanReview: Bool
    let analyzedAt: Date
    var id: String { analysisId }

    init(analysisId: String, kind: AnalysisKind, riskScore: Int, summary: String,
         signals: [String], recommendedActions: [String], source: AssessmentSource,
         requiresHumanReview: Bool, analyzedAt: Date) throws {
        self.analysisId = analysisId
        self.kind = kind
        self.riskScore = riskScore
        self.riskLevel = try RiskLevel.forScore(riskScore)
        self.summary = summary
        self.signals = signals
        self.recommendedActions = recommendedActions
        self.source = source
        self.requiresHumanReview = requiresHumanReview
        self.analyzedAt = analyzedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(analysisId: c.decode(String.self, forKey: .analysisId),
                      kind: c.decode(AnalysisKind.self, forKey: .kind),
                      riskScore: c.decode(Int.self, forKey: .riskScore),
                      summary: c.decode(String.self, forKey: .summary),
                      signals: c.decode([String].self, forKey: .signals),
                      recommendedActions: c.decode([String].self, forKey: .recommendedActions),
                      source: c.decode(AssessmentSource.self, forKey: .source),
                      requiresHumanReview: c.decode(Bool.self, forKey: .requiresHumanReview),
                      analyzedAt: c.decode(Date.self, forKey: .analyzedAt))
        guard try c.decode(RiskLevel.self, forKey: .riskLevel) == riskLevel else {
            throw AssessmentValidationError.mismatchedLevel
        }
    }
}

struct APIErrorEnvelope: Codable, Equatable, Sendable {
    let error: Detail
    struct Detail: Codable, Equatable, Sendable {
        let code: String
        let message: String
        let requestId: String
    }
}

enum APIJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO 8601 timestamp.")
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}
