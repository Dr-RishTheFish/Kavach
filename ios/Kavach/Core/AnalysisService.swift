import Foundation

protocol AnalysisService: Sendable {
    func analyze(_ request: AnalysisRequest) async throws -> RiskAssessment
}

enum AnalysisServiceError: Error, LocalizedError {
    case invalidBaseURL, invalidResponse, httpStatus(Int), api(Int, APIErrorEnvelope.Detail)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL: return "Enter an HTTP or HTTPS server address without credentials, a query, or a fragment."
        case .invalidResponse: return "The server returned an unexpected response."
        case .httpStatus(let status): return "The server could not complete the request (HTTP \(status))."
        case .api(_, let detail): return detail.message
        }
    }
}

struct HTTPAnalysisService: AnalysisService {
    let baseURL: URL
    let session: URLSession
    let timeout: TimeInterval

    init(baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 20) throws {
        guard ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""),
              let host = baseURL.host, !host.isEmpty, baseURL.user == nil,
              baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else {
            throw AnalysisServiceError.invalidBaseURL
        }
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
    }

    func analyze(_ request: AnalysisRequest) async throws -> RiskAssessment {
        try Task.checkCancellation()
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/v1/analyze"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try APIJSON.encoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw AnalysisServiceError.invalidResponse }
        guard response.statusCode == 200 else {
            if let envelope = try? APIJSON.decoder().decode(APIErrorEnvelope.self, from: data) {
                throw AnalysisServiceError.api(response.statusCode, envelope.error)
            }
            throw AnalysisServiceError.httpStatus(response.statusCode)
        }
        let assessment = try APIJSON.decoder().decode(RiskAssessment.self, from: data)
        guard assessment.kind == request.kind else { throw AnalysisServiceError.invalidResponse }
        return assessment
    }
}

struct MockAnalysisService: AnalysisService {
    func analyze(_ request: AnalysisRequest) async throws -> RiskAssessment {
        try Task.checkCancellation()
        // Exact synthetic fixtures only: this is not a general scam classifier.
        let scenario = DemoScenario.allCases.first { $0.request.content == request.content }
        return try (scenario ?? .unknownContact).assessment(kind: request.kind, unrecognized: scenario == nil)
    }
}
