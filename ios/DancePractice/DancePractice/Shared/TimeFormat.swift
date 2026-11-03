//
//  TimeFormat.swift
//  DancePractice
//

import Foundation

/// Display strings for times and durations. Words come from the string catalog,
/// dates from the user's locale, so these follow the device language.
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

    /// Practice totals: "Under 1 min", "45 min", "2 h", "3.5 h".
    static func practiceDuration(_ seconds: Double) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        if safe < 60 { return String(localized: "Under 1 min") }
        let parts = durationParts(safe)
        return "\(parts.value) \(parts.unit)"
    }

    /// Number and unit apart, for big-number stat tiles: ("45", "min"), ("3.5", "h"), ("0", "min").
    static func durationParts(_ seconds: Double) -> (value: String, unit: String) {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        if safe < 3600 { return (String(Int(safe / 60)), String(localized: "min", comment: "Unit after a number of minutes")) }
        let hours = (safe / 3600 * 10).rounded() / 10
        let text = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
        return (text, String(localized: "h", comment: "Unit after a number of hours"))
    }

    /// Unit after a streak count: "day" / "days".
    static func dayUnit(_ count: Int) -> String {
        count == 1
            ? String(localized: "day", comment: "Unit after the number 1")
            : String(localized: "days", comment: "Unit after a number of days other than 1")
    }

    /// "Today 20:12", "Yesterday 18:45", "3 days ago", or "Oct 2" beyond a week.
    static func lastPracticed(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let clock = String(format: "%02d:%02d", time.hour ?? 0, time.minute ?? 0)
        switch days {
        case ...0: return String(localized: "Today \(clock)")
        case 1: return String(localized: "Yesterday \(clock)")
        case 2..<7: return String(localized: "\(days) days ago")
        default: return monthDay(date, calendar: calendar)
        }
    }

    /// "Oct 2" / "10月2日".
    static func monthDay(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(dateStyle(calendar).month(.abbreviated).day())
    }

    /// "Mon, Oct 2" / "10月2日 周一".
    static func monthDayWeekday(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(dateStyle(calendar).month(.abbreviated).day().weekday(.abbreviated))
    }

    /// Weekday names starting on Monday, in the user's language: very short ("M", "一") and full ("Monday", "星期一").
    static func mondayFirstWeekdays(calendar: Calendar = .current) -> (short: [String], full: [String]) {
        func mondayFirst(_ symbols: [String]) -> [String] { Array(symbols.dropFirst()) + [symbols[0]] }
        return (mondayFirst(calendar.veryShortStandaloneWeekdaySymbols), mondayFirst(calendar.standaloneWeekdaySymbols))
    }

    private static func dateStyle(_ calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
    }
}
