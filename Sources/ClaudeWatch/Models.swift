import Foundation

// MARK: - Credentials

/// OAuth credentials as Claude Code stores them in the macOS Keychain
/// (item "Claude Code-credentials", key `claudeAiOauth`).
struct OAuthCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    /// Milliseconds since epoch.
    let expiresAt: Double
    let subscriptionType: String?

    var isExpired: Bool {
        // Refresh a minute early so a request never races the expiry.
        Date(timeIntervalSince1970: expiresAt / 1000) < Date().addingTimeInterval(60)
    }
}

/// One Claude subscription tracked by the app. The active account's tokens
/// are always re-read from Claude Code's Keychain item; for the inactive one
/// we keep the last snapshot and refresh it ourselves.
struct StoredAccount: Codable, Equatable, Identifiable {
    let uuid: String
    let email: String
    let credentials: OAuthCredentials

    var id: String { uuid }

    func withCredentials(_ newCredentials: OAuthCredentials) -> StoredAccount {
        StoredAccount(uuid: uuid, email: email, credentials: newCredentials)
    }
}

// MARK: - API responses

/// Response of `GET /api/oauth/profile` (only the fields we need).
struct ProfileResponse: Codable {
    struct Account: Codable {
        let uuid: String
        let email: String
    }
    let account: Account
}

/// Response of `POST /v1/oauth/token` (refresh grant).
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    /// Seconds until expiry.
    let expiresIn: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// Response of `GET /api/oauth/usage`. The `limits` array carries everything
/// the /usage screen in Claude Code shows: session (5h), weekly and
/// per-model weekly utilization.
struct UsageResponse: Codable, Equatable {
    let limits: [UsageLimit]
}

struct UsageLimit: Codable, Equatable {
    struct Scope: Codable, Equatable {
        struct Model: Codable, Equatable {
            let displayName: String?
        }
        let model: Model?
    }

    /// "session" | "weekly_all" | "weekly_scoped"
    let kind: String
    let percent: Double
    /// "normal" | "warning" | "critical" (API wording may evolve; treated loosely)
    let severity: String?
    let resetsAt: Date?
    let scope: Scope?
    let isActive: Bool?

    var label: String {
        switch kind {
        case "session":
            return "Session (5 h)"
        case "weekly_all":
            return "Týden (vše)"
        case "weekly_scoped":
            if let model = scope?.model?.displayName {
                return "Týden (\(model))"
            }
            return "Týden (model)"
        default:
            return kind
        }
    }
}

// MARK: - UI state

/// Everything the dashboard needs to render one account.
struct AccountStatus: Identifiable, Equatable {
    let account: StoredAccount
    let isActive: Bool
    let usage: UsageResponse?
    let error: String?
    let updatedAt: Date?

    var id: String { account.uuid }

    /// The session (5h) limit drives the menu bar readout.
    var sessionLimit: UsageLimit? {
        usage?.limits.first { $0.kind == "session" }
    }
}
