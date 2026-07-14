import Foundation
import Combine

/// Central state: discovers the active Claude Code account from the Keychain,
/// keeps snapshots of every account seen, refreshes inactive tokens itself and
/// polls the usage endpoint for all of them.
@MainActor
final class UsageStore: ObservableObject {

    @Published private(set) var statuses: [AccountStatus] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var globalError: String?

    private var accounts: [StoredAccount] = KeychainService.loadAccounts()
    private var activeUUID: String?
    /// Cache: access token -> account uuid, spares a profile call per tick.
    private var tokenOwner: [String: String] = [:]
    private var timer: Timer?
    /// Set after an HTTP 429 — no network calls until it passes.
    private var cooldownUntil: Date?

    static let pollInterval: TimeInterval = 120
    static let rateLimitCooldown: TimeInterval = 300
    /// Manual refresh (popover open, button) is a no-op this soon after a sync.
    static let manualRefreshThrottle: TimeInterval = 30
    /// Gap between per-account requests — the endpoint 429s on quick bursts.
    static let interAccountDelay: TimeInterval = 10

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.sync() }
        }
        Task { await sync() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        if let lastSync, Date().timeIntervalSince(lastSync) < Self.manualRefreshThrottle {
            return
        }
        Task { await sync() }
    }

    // MARK: - Sync pipeline

    func sync() async {
        if let cooldownUntil, cooldownUntil > Date() { return }
        self.cooldownUntil = nil
        await adoptActiveAccount()
        var results: [AccountStatus] = []
        for (index, account) in accounts.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: UInt64(Self.interAccountDelay * 1_000_000_000))
            }
            results.append(await status(for: account))
        }
        // Active account first, then by email for a stable order.
        statuses = results.sorted {
            ($0.isActive ? 0 : 1, $0.account.email) < ($1.isActive ? 0 : 1, $1.account.email)
        }
        lastSync = Date()
    }

    /// Reads Claude Code's Keychain item and upserts whichever account is
    /// logged in right now. Its tokens always win over our snapshot.
    private func adoptActiveAccount() async {
        guard let credentials = KeychainService.readClaudeCodeCredentials() else {
            globalError = accounts.isEmpty
                ? "Claude Code není přihlášený (Keychain je prázdný)."
                : nil
            activeUUID = nil
            return
        }
        globalError = nil

        if let uuid = tokenOwner[credentials.accessToken] {
            activeUUID = uuid
            updateAccount(uuid: uuid) { $0.withCredentials(credentials) }
            return
        }

        do {
            let profile = try await AnthropicAPI.fetchProfile(accessToken: credentials.accessToken)
            tokenOwner[credentials.accessToken] = profile.account.uuid
            activeUUID = profile.account.uuid
            let adopted = StoredAccount(
                uuid: profile.account.uuid,
                email: profile.account.email,
                credentials: credentials
            )
            upsert(adopted)
        } catch {
            // Profile lookup failed (offline?) — keep previous state, retry next tick.
            globalError = "Nepodařilo se ověřit aktivní účet: \(error.localizedDescription)"
        }
    }

    private func status(for account: StoredAccount) async -> AccountStatus {
        let isActive = account.uuid == activeUUID
        do {
            let token = try await validToken(for: account, isActive: isActive)
            let usage = try await AnthropicAPI.fetchUsage(accessToken: token)
            return AccountStatus(account: account, isActive: isActive, usage: usage, error: nil, updatedAt: Date())
        } catch {
            var isRateLimit = false
            if case APIError.http(429) = error {
                isRateLimit = true
                cooldownUntil = Date().addingTimeInterval(Self.rateLimitCooldown)
            }
            let previous = statuses.first { $0.id == account.uuid }
            // 429 with data on screen: degrade silently, footer shows staleness.
            let silent = isRateLimit && previous?.usage != nil
            return AccountStatus(
                account: account,
                isActive: isActive,
                usage: previous?.usage,
                error: silent ? nil : error.localizedDescription,
                updatedAt: previous?.updatedAt
            )
        }
    }

    /// Active account: use the Keychain token as-is (Claude Code refreshes it).
    /// Inactive account: refresh ourselves once the snapshot expires.
    private func validToken(for account: StoredAccount, isActive: Bool) async throws -> String {
        guard !isActive, account.credentials.isExpired else {
            return account.credentials.accessToken
        }
        let refreshed = try await AnthropicAPI.refresh(refreshToken: account.credentials.refreshToken)
        let newCredentials = OAuthCredentials(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            expiresAt: (Date().timeIntervalSince1970 + refreshed.expiresIn) * 1000,
            subscriptionType: account.credentials.subscriptionType
        )
        updateAccount(uuid: account.uuid) { $0.withCredentials(newCredentials) }
        return newCredentials.accessToken
    }

    // MARK: - Account list mutations (persisted)

    func forget(uuid: String) {
        accounts = accounts.filter { $0.uuid != uuid }
        statuses = statuses.filter { $0.id != uuid }
        KeychainService.saveAccounts(accounts)
    }

    private func upsert(_ account: StoredAccount) {
        if accounts.contains(where: { $0.uuid == account.uuid }) {
            updateAccount(uuid: account.uuid) { _ in account }
        } else {
            accounts = accounts + [account]
            KeychainService.saveAccounts(accounts)
        }
    }

    private func updateAccount(uuid: String, transform: (StoredAccount) -> StoredAccount) {
        let updated = accounts.map { $0.uuid == uuid ? transform($0) : $0 }
        guard updated != accounts else { return }
        accounts = updated
        KeychainService.saveAccounts(accounts)
    }

    // MARK: - Menu bar readout

    /// Session utilization of the active account (fallback: first account).
    var menuBarLimit: UsageLimit? {
        let primary = statuses.first { $0.isActive } ?? statuses.first
        return primary?.sessionLimit
    }
}
