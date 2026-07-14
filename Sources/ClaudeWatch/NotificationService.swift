import Foundation
import UserNotifications

/// Local notifications for usage-limit events, driven off each poll's fresh
/// statuses. Edge-triggered against the previous poll so a steady state never
/// repeats the same alert. Fires on two edges:
///   1. a limit window resetting (freed capacity), and
///   2. a limit crossing the "almost exhausted" threshold upward.
@MainActor
final class NotificationService {

    /// Fire the "almost exhausted" alert when a limit crosses up to this percent.
    static let nearLimitThreshold: Double = 90
    /// Only announce a reset if the window had been used at least this much —
    /// a window that was barely touched rolling over isn't worth a ping.
    static let resetAnnounceThreshold: Double = 50
    /// Tolerance (seconds) for treating a later `resetsAt` as a real window roll.
    static let resetJumpTolerance: TimeInterval = 60

    /// One limit's state as of the last poll.
    private struct Snapshot {
        let percent: Double
        let resetsAt: Date?
    }

    /// Key "uuid|kind|model" -> last seen snapshot.
    private var previous: [String: Snapshot] = [:]
    private var authorized = false

    /// Ask once, at launch. Silently no-ops if the user declines.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.authorized = granted }
        }
    }

    /// Diff the new statuses against the previous poll and emit notifications
    /// for any limit that reset or crossed the near-limit threshold.
    func process(_ statuses: [AccountStatus]) {
        for status in statuses {
            guard let limits = status.usage?.limits else { continue }
            for limit in limits {
                let model = limit.scope?.model?.displayName ?? ""
                let key = "\(status.account.uuid)|\(limit.kind)|\(model)"
                let current = Snapshot(percent: limit.percent, resetsAt: limit.resetsAt)
                defer { previous[key] = current }

                // No baseline yet (first poll for this limit): just record it,
                // otherwise every limit would alert on the very first tick.
                guard let old = previous[key] else { continue }

                if didReset(old: old, current: current) {
                    notify(
                        title: "Limit se uvolnil",
                        body: "\(status.account.email): \(limit.label) — reset proběhl (bylo \(Format.percent(old.percent)))."
                    )
                }

                if crossedNearLimit(old: old, current: current) {
                    notify(
                        title: "Limit skoro vyčerpán",
                        body: "\(status.account.email): \(limit.label) na \(Format.percent(current.percent))."
                    )
                }
            }
        }
    }

    // MARK: - Edge detection

    /// A window reset when its `resetsAt` jumped to a later time and it had
    /// been meaningfully used beforehand.
    private func didReset(old: Snapshot, current: Snapshot) -> Bool {
        guard let oldReset = old.resetsAt, let newReset = current.resetsAt else { return false }
        return newReset.timeIntervalSince(oldReset) > Self.resetJumpTolerance
            && old.percent >= Self.resetAnnounceThreshold
    }

    /// Crossed the near-limit threshold going up (only on the crossing tick).
    private func crossedNearLimit(old: Snapshot, current: Snapshot) -> Bool {
        old.percent < Self.nearLimitThreshold && current.percent >= Self.nearLimitThreshold
    }

    // MARK: - Delivery

    private func notify(title: String, body: String) {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
