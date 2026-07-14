import AppKit
import SwiftUI
import Combine

/// Menu bar controller. Owns the status item, the shared `UsageStore` and a
/// popover hosting the SwiftUI dashboard. The status item shows a small
/// colored progress bar + the active account's session utilization.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = UsageStore()
    private let notifications = NotificationService()
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }
        updateStatusItem(with: nil)

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(store: store, onQuit: {
                NSApplication.shared.terminate(nil)
            })
        )

        cancellable = store.$statuses.sink { [weak self] statuses in
            DispatchQueue.main.async {
                guard let self else { return }
                self.updateStatusItem(with: self.store.menuBarLimit)
                self.notifications.process(statuses)
            }
        }
        notifications.requestAuthorization()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    // MARK: - Status item rendering

    private func updateStatusItem(with limit: UsageLimit?) {
        guard let button = statusItem.button else { return }
        button.image = Self.barImage(percent: limit?.percent)
        button.toolTip = limit.map {
            var parts = ["Session: \(Format.percent($0.percent))"]
            if let resetsAt = $0.resetsAt {
                parts.append("reset \(Format.countdown(to: resetsAt))")
            }
            return parts.joined(separator: ", ")
        } ?? "ClaudeWatch: načítám…"
    }

    /// The whole menu bar item: a small hand-drawn progress bar, no text.
    /// A hairline capsule outline with a tiny inner gap makes the bar read
    /// against any menu bar background; the colored fill sits inset inside.
    private static func barImage(percent: Double?) -> NSImage {
        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 9
        let borderWidth: CGFloat = 1
        let innerPadding: CGFloat = 1.5
        let size = NSSize(width: barWidth, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let barRect = NSRect(x: 0, y: (16 - barHeight) / 2, width: barWidth, height: barHeight)

            // Hairline outline (inset by half the line width so it isn't clipped).
            let outlineRect = barRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let outline = NSBezierPath(
                roundedRect: outlineRect,
                xRadius: outlineRect.height / 2,
                yRadius: outlineRect.height / 2
            )
            outline.lineWidth = borderWidth
            NSColor.labelColor.withAlphaComponent(0.85).setStroke()
            outline.stroke()

            if let percent {
                let inset = borderWidth + innerPadding
                let fillArea = barRect.insetBy(dx: inset, dy: inset)
                let fraction = min(max(percent / 100, 0), 1)
                let fillWidth = max(fillArea.width * fraction, fillArea.height)
                let fillRect = NSRect(
                    x: fillArea.minX, y: fillArea.minY,
                    width: fillWidth, height: fillArea.height
                )
                let fill = NSBezierPath(
                    roundedRect: fillRect,
                    xRadius: fillRect.height / 2,
                    yRadius: fillRect.height / 2
                )
                Format.usageColor(percent: percent).setFill()
                fill.fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Interaction

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Obnovit teď", action: #selector(refreshClicked), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Ukončit ClaudeWatch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshClicked() {
        store.refreshNow()
    }
}
