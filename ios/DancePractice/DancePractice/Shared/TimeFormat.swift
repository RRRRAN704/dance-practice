//
//  TimeFormat.swift
//  DancePractice
//

import Foundation

enum TimeFormat {
    /// "03:18"
    static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// "00:32.4" — used for A-B points where tenths matter.
    static func precise(_ seconds: Double) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        let tenths = Int((safe * 10).rounded(.down))
        return String(format: "%02d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }

    /// Practice totals: "不到 1 分钟", "45 分钟", "2 小时", "3.5 小时".
    static func practiceDuration(_ seconds: Double) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        if safe < 60 { return "不到 1 分钟" }
        if safe < 3600 { return "\(Int(safe / 60)) 分钟" }
        let hours = (safe / 3600 * 10).rounded() / 10
        let text = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
        return "\(text) 小时"
    }

    /// "今天 20:12", "昨天 18:45", "3 天前", or "10月2日" beyond a week.
    static func lastPracticed(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let clock = String(format: "%02d:%02d", time.hour ?? 0, time.minute ?? 0)
        switch days {
        case ...0: return "今天 \(clock)"
        case 1: return "昨天 \(clock)"
        case 2..<7: return "\(days) 天前"
        default:
            let parts = calendar.dateComponents([.month, .day], from: date)
            return "\(parts.month ?? 0)月\(parts.day ?? 0)日"
        }
    }
}
