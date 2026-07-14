import Foundation

enum APIError: LocalizedError {
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .http(401):
            return "Token vypršel (401)"
        case .http(429):
            return "API rate limit, chvíli počkám…"
        case .http(let code):
            return "HTTP \(code)"
        case .invalidResponse:
            return "Neplatná odpověď API"
        }
    }
}

/// Thin async client for the Anthropic OAuth endpoints Claude Code itself uses.
enum AnthropicAPI {

    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let profileURL = URL(string: "https://api.anthropic.com/api/oauth/profile")!
    private static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    /// Claude Code's public OAuth client id.
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    static func fetchUsage(accessToken: String) async throws -> UsageResponse {
        try await get(usageURL, accessToken: accessToken)
    }

    static func fetchProfile(accessToken: String) async throws -> ProfileResponse {
        try await get(profileURL, accessToken: accessToken)
    }

    /// Exchanges a refresh token for a fresh token pair. Only ever called for
    /// the account that is NOT active in Claude Code — refreshing the active
    /// one would rotate the refresh token under Claude Code's feet.
    static func refresh(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - Helpers

    private static func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkStatus(response)
        return try Self.decoder.decode(T.self, from: data)
    }

    private static func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
    }

    /// Usage payload uses snake_case and ISO8601 dates with fractional seconds.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: value) ?? fallback.date(from: value) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Nerozpoznané datum: \(value)"
            ))
        }
        return decoder
    }()
}
