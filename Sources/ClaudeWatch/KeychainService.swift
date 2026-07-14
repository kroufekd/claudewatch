import Foundation

/// Reads Claude Code's credentials and persists ClaudeWatch's own account
/// snapshots. Both live in the login Keychain; Claude Code's item is read
/// through `/usr/bin/security` (Apple-signed, already trusted for that item),
/// our own item is written the same way for symmetry.
enum KeychainService {

    private static let claudeCodeService = "Claude Code-credentials"
    private static let ownService = "ClaudeWatch-accounts"

    // MARK: - Claude Code credentials (read-only)

    /// Returns the currently logged-in Claude Code account's OAuth credentials,
    /// or nil when nobody is logged in / the item is missing.
    static func readClaudeCodeCredentials() -> OAuthCredentials? {
        guard let raw = readPassword(service: claudeCodeService),
              let data = raw.data(using: .utf8) else { return nil }
        struct Wrapper: Codable { let claudeAiOauth: OAuthCredentials? }
        return (try? JSONDecoder().decode(Wrapper.self, from: data))?.claudeAiOauth
    }

    // MARK: - Own account store

    static func loadAccounts() -> [StoredAccount] {
        guard let raw = readPassword(service: ownService),
              let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StoredAccount].self, from: data)) ?? []
    }

    static func saveAccounts(_ accounts: [StoredAccount]) {
        guard let data = try? JSONEncoder().encode(accounts),
              let json = String(data: data, encoding: .utf8) else { return }
        writePassword(service: ownService, value: json)
    }

    // MARK: - `security` CLI plumbing

    private static func readPassword(service: String) -> String? {
        let output = runSecurity(["find-generic-password", "-s", service, "-w"])
        guard let output, !output.isEmpty else { return nil }
        return output
    }

    private static func writePassword(service: String, value: String) {
        // -U updates in place when the item already exists.
        _ = runSecurity([
            "add-generic-password", "-U",
            "-s", service,
            "-a", NSUserName(),
            "-w", value
        ])
    }

    private static func runSecurity(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
