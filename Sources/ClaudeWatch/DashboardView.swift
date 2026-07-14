import SwiftUI

/// Popover content. Hero = the active account's session (5h) limit: big
/// remaining-percent number and countdown to reset. Everything else (weekly
/// limits, other accounts) sits behind a disclosure.
struct DashboardView: View {
    @ObservedObject var store: UsageStore
    let onQuit: () -> Void
    @State private var showDetails = false

    private var primary: AccountStatus? {
        store.statuses.first { $0.isActive } ?? store.statuses.first
    }

    private var others: [AccountStatus] {
        store.statuses.filter { $0.id != primary?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let primary {
                HeroSection(status: primary)
            } else {
                Text(store.globalError ?? "Zatím žádná data — přihlas se v Claude Code (`/login`).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if primary?.usage != nil || !others.isEmpty {
                detailsDisclosure
            }

            if let error = store.globalError, primary != nil {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            footer
        }
        .padding(16)
        .frame(width: 300)
        .focusEffectDisabledCompat()
    }

    private var detailsDisclosure: some View {
        DisclosureGroup(isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 10) {
                if let primary, let usage = primary.usage {
                    let weekly = usage.limits.filter { $0.kind != "session" }
                    ForEach(weekly.indices, id: \.self) { index in
                        LimitRow(limit: weekly[index])
                    }
                }
                ForEach(others) { status in
                    AccountCard(status: status, onForget: { store.forget(uuid: status.id) })
                }
            }
            .padding(.top, 10)
        } label: {
            Text("Další limity a účty")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if let lastSync = store.lastSync {
                Text("Aktualizováno \(Format.time(lastSync))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                store.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Obnovit teď")
            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Ukončit ClaudeWatch")
        }
    }
}

private extension View {
    /// Kills the keyboard focus ring the popover otherwise draws around its
    /// first focusable control (the disclosure). `.focusEffectDisabled()` is
    /// macOS 14+, so no-op on the deployment floor (macOS 13).
    @ViewBuilder
    func focusEffectDisabledCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

/// Big session readout: remaining %, countdown to reset, thick progress bar.
private struct HeroSection: View {
    let status: AccountStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(status.account.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let plan = status.account.credentials.subscriptionType {
                    Text(plan.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().stroke(.secondary.opacity(0.5), lineWidth: 1))
                }
                Spacer()
            }

            if let session = status.sessionLimit {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.percent(session.percent))
                                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color(nsColor: Format.usageColor(percent: session.percent)))
                            Text("využito ze session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let resetsAt = session.resetsAt {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Format.duration(to: resetsAt, from: context.date))
                                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                                Text("do resetu v \(Format.time(resetsAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                ProgressBar(percent: session.percent, height: 10)
            } else if status.error == nil {
                Text("Načítám usage…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let error = status.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Compact card for an inactive account inside the disclosure.
private struct AccountCard: View {
    let status: AccountStatus
    let onForget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(status.account.email)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    onForget()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Přestat sledovat tento účet")
            }

            if let usage = status.usage {
                ForEach(usage.limits.indices, id: \.self) { index in
                    LimitRow(limit: usage.limits[index])
                }
            }

            if let error = status.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct LimitRow: View {
    let limit: UsageLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(limit.label)
                    .font(.caption)
                Spacer()
                if let resetsAt = limit.resetsAt {
                    Text("reset \(Format.countdown(to: resetsAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(Format.percent(limit.percent))
                    .font(.caption.monospacedDigit().weight(.medium))
            }
            ProgressBar(percent: limit.percent, height: 6)
        }
    }
}

private struct ProgressBar: View {
    let percent: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(Color(nsColor: Format.usageColor(percent: percent)).gradient)
                    .frame(width: max(geometry.size.width * min(percent, 100) / 100, height))
            }
        }
        .frame(height: height)
    }
}
