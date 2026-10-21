import Foundation

enum CursorAPI {
    private static let api2 = URL(string: "https://api2.cursor.sh")!
    private static let web = URL(string: "https://cursor.com")!

    // MARK: - Response models

    struct PlanUsage: Codable, Sendable {
        let totalSpend: Double?
        let includedSpend: Double?
        let bonusSpend: Double?
        let remaining: Double?
        let limit: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
        let totalPercentUsed: Double?
    }

    struct PeriodUsageResponse: Codable, Sendable {
        let billingCycleStart: String?
        let billingCycleEnd: String?
        let planUsage: PlanUsage?
        let displayMessage: String?
    }

    struct PlanInfoResponse: Codable, Sendable {
        struct PlanInfo: Codable, Sendable {
            let planName: String?
            let includedAmountCents: Double?
            let price: String?
            let billingCycleEnd: String?
        }
        let planInfo: PlanInfo?
    }

    struct UsageSummaryResponse: Codable, Sendable {
        let billingCycleStart: String?
        let billingCycleEnd: String?
        let membershipType: String?
        let isUnlimited: Bool?
        let autoModelSelectedDisplayMessage: String?
        let namedModelSelectedDisplayMessage: String?
        let individualUsage: IndividualUsage?

        struct IndividualUsage: Codable, Sendable {
            let plan: Bucket?
            let onDemand: Bucket?
        }

        struct Bucket: Codable, Sendable {
            let enabled: Bool?
            let used: Double?
            let limit: Double?
            let remaining: Double?
            let autoPercentUsed: Double?
            let apiPercentUsed: Double?
            let totalPercentUsed: Double?
        }
    }

    struct FilteredEventsResponse: Codable, Sendable {
        let totalUsageEventsCount: Int?
        let usageEventsDisplay: [UsageEvent]?
    }

    struct UsageEvent: Codable, Sendable {
        let timestamp: String?
        let model: String?
        let tokenUsage: TokenUsage?
        let chargedCents: Double?
        let requestsCosts: Double?
    }

    struct TokenUsage: Codable, Sendable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheWriteTokens: Int?
        let cacheReadTokens: Int?
        let totalCents: Double?
    }

    enum APIError: Error, LocalizedError {
        case http(Int, String?)
        case decode(Error)
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .http(let code, let body):
                return "HTTP \(code)\(body.map { ": \($0)" } ?? "")"
            case .decode(let error):
                return "Decode: \(error.localizedDescription)"
            case .network(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Public fetches

    static func fetchCurrentPeriodUsage(token: String) async throws -> PeriodUsageResponse {
        try await postConnect(
            path: "/aiserver.v1.DashboardService/GetCurrentPeriodUsage",
            token: token,
            body: Data("{}".utf8)
        )
    }

    static func fetchPlanInfo(token: String) async throws -> PlanInfoResponse {
        try await postConnect(
            path: "/aiserver.v1.DashboardService/GetPlanInfo",
            token: token,
            body: Data("{}".utf8)
        )
    }

    static func fetchUsageSummary(cookieHeader: String) async throws -> UsageSummaryResponse {
        var request = URLRequest(url: web.appendingPathComponent("/api/usage-summary"))
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        return try await perform(request)
    }

    static func fetchUsageEvents(
        cookieHeader: String,
        start: Date?,
        end: Date?,
        pageSize: Int = 200
    ) async throws -> FilteredEventsResponse {
        var body: [String: Any] = [
            "page": 1,
            "pageSize": pageSize
        ]
        if let start {
            body["startDate"] = String(Int(start.timeIntervalSince1970 * 1000))
        }
        if let end {
            body["endDate"] = String(Int(end.timeIntervalSince1970 * 1000))
        }

        var request = URLRequest(url: web.appendingPathComponent("/api/dashboard/get-filtered-usage-events"))
        request.httpMethod = "POST"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    // MARK: - Internals

    private static func postConnect<T: Decodable>(
        path: String,
        token: String,
        body: Data
    ) async throws -> T {
        var request = URLRequest(url: api2.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private static func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.http(0, nil)
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw APIError.http(http.statusCode, body)
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decode(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }
}
