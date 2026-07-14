import AppKit

enum Format {

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded())) %"
    }

    /// "za 2 h 05 min" — countdown to a limit reset.
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 {
            return "za \(days) d \(hours) h"
        }
        if hours > 0 {
            return "za \(hours) h \(String(format: "%02d", minutes)) min"
        }
        return "za \(minutes) min"
    }

    /// "1 h 52 min" — plain duration, no prefix (hero readout).
    static func duration(to date: Date, from now: Date = Date()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) h \(String(format: "%02d", minutes)) min"
        }
        return "\(minutes) min"
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Shared traffic-light scale for bars and the menu bar icon.
    static func usageColor(percent: Double) -> NSColor {
        switch percent {
        case ..<60: return .systemGreen
        case ..<85: return .systemOrange
        default: return .systemRed
        }
    }
}
