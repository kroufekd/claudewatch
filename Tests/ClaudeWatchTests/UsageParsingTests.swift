import XCTest
@testable import ClaudeWatch

final class UsageParsingTests: XCTestCase {

    /// Trimmed real payload of GET /api/oauth/usage.
    private let sampleJSON = """
    {
      "five_hour": {"utilization": 38.0, "resets_at": "2026-07-14T00:59:59.529533+00:00"},
      "seven_day": {"utilization": 17.0, "resets_at": "2026-07-19T22:59:59.529555+00:00"},
      "limits": [
        {"kind": "session", "group": "session", "percent": 38, "severity": "normal",
         "resets_at": "2026-07-14T00:59:59.529533+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_all", "group": "weekly", "percent": 17, "severity": "normal",
         "resets_at": "2026-07-19T22:59:59.529555+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 15, "severity": "normal",
         "resets_at": "2026-07-19T22:59:59.529835+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}, "is_active": false}
      ]
    }
    """

    func testDecodesLimits() throws {
        let usage = try AnthropicAPI.decoder.decode(UsageResponse.self, from: Data(sampleJSON.utf8))
        XCTAssertEqual(usage.limits.count, 3)

        let session = try XCTUnwrap(usage.limits.first { $0.kind == "session" })
        XCTAssertEqual(session.percent, 38)
        XCTAssertEqual(session.label, "Session (5 h)")
        XCTAssertNotNil(session.resetsAt)

        let scoped = try XCTUnwrap(usage.limits.first { $0.kind == "weekly_scoped" })
        XCTAssertEqual(scoped.label, "Týden (Fable)")
    }

    func testDecodesDateWithFractionalSeconds() throws {
        let usage = try AnthropicAPI.decoder.decode(UsageResponse.self, from: Data(sampleJSON.utf8))
        let session = try XCTUnwrap(usage.limits.first { $0.kind == "session" })
        let resetsAt = try XCTUnwrap(session.resetsAt)
        // 2026-07-14T00:59:59Z
        XCTAssertEqual(resetsAt.timeIntervalSince1970, 1784077199, accuracy: 1.0)
    }

    func testCredentialsExpiry() {
        let expired = OAuthCredentials(
            accessToken: "a", refreshToken: "r",
            expiresAt: Date().addingTimeInterval(-10).timeIntervalSince1970 * 1000,
            subscriptionType: "max"
        )
        XCTAssertTrue(expired.isExpired)

        let fresh = OAuthCredentials(
            accessToken: "a", refreshToken: "r",
            expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000,
            subscriptionType: "max"
        )
        XCTAssertFalse(fresh.isExpired)
    }

    func testCountdownFormatting() {
        let now = Date()
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(125 * 60), from: now), "za 2 h 05 min")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(9 * 60), from: now), "za 9 min")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(26 * 3600), from: now), "za 1 d 2 h")
        XCTAssertEqual(Format.countdown(to: now.addingTimeInterval(-60), from: now), "za 0 min")
    }

    func testUsageColorThresholds() {
        XCTAssertEqual(Format.usageColor(percent: 10), .systemGreen)
        XCTAssertEqual(Format.usageColor(percent: 70), .systemOrange)
        XCTAssertEqual(Format.usageColor(percent: 95), .systemRed)
    }
}
