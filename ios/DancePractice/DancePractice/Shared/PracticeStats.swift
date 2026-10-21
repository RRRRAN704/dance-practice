//
//  PracticeStats.swift
//  DancePractice
//

import Foundation

/// Pure calculations over practice sessions, shared by Home and Stats.
/// Every function takes `now` and a calendar so tests don't depend on the clock or locale.
enum PracticeStats {
    /// Weeks start on Monday, as in the 一…日 dot row.
    static func calendar(base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        return calendar
    }

    static func total(_ sessions: [PracticeSession], in interval: DateInterval) -> TimeInterval {
        sessions
            .filter { interval.contains($0.startedAt) }
            .reduce(0) { $0 + $1.duration }
    }

    static func today(_ sessions: [PracticeSession], now: Date = .now, calendar: Calendar) -> TimeInterval {
        guard let day = calendar.dateInterval(of: .day, for: now) else { return 0 }
        return total(sessions, in: day)
    }

    static func thisWeek(_ sessions: [PracticeSession], now: Date = .now, calendar: Calendar) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return total(sessions, in: week)
    }

    /// Start of every day that has at least one session.
    static func practicedDays(_ startDates: [Date], calendar: Calendar) -> Set<Date> {
        Set(startDates.map { calendar.startOfDay(for: $0) })
    }

    /// Consecutive practiced days ending today, or ending yesterday if today has nothing yet,
    /// so the streak doesn't read 0 every morning.
    static func currentStreak(days: Set<Date>, now: Date = .now, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// The seven day-starts of the week containing `now`, Monday first.
    static func weekDays(now: Date = .now, calendar: Calendar) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }
}
