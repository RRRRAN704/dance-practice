//
//  PracticeStats.swift
//  DancePractice
//

import Foundation

/// One day's practice total, a bar or heatmap cell.
struct DayTotal: Identifiable, Equatable {
    let day: Date
    let seconds: TimeInterval
    var id: Date { day }
}

/// Practice time for one genre; nil genre means 未分类.
struct GenreShare: Identifiable, Equatable {
    let genre: DanceGenre?
    let seconds: TimeInterval
    var id: String { genre?.rawValue ?? "unset" }
}

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

    static func thisMonth(_ sessions: [PracticeSession], now: Date = .now, calendar: Calendar) -> TimeInterval {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return total(sessions, in: month)
    }

    /// Longest run of consecutive practiced days ever.
    static func longestStreak(days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        for day in days {
            // Only count from the first day of each run.
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day),
                  !days.contains(previous) else { continue }
            var length = 1
            var next = day
            while let following = calendar.date(byAdding: .day, value: 1, to: next), days.contains(following) {
                length += 1
                next = following
            }
            longest = max(longest, length)
        }
        return longest
    }

    /// Seconds practiced per day-start, for charts and the heatmap.
    static func totalsByDay(_ sessions: [PracticeSession], calendar: Calendar) -> [Date: TimeInterval] {
        sessions.reduce(into: [:]) { totals, session in
            totals[calendar.startOfDay(for: session.startedAt), default: 0] += session.duration
        }
    }

    /// The last `count` days ending today, oldest first, with each day's total (0 when unpracticed).
    static func recentDays(
        _ totals: [Date: TimeInterval],
        count: Int,
        now: Date = .now,
        calendar: Calendar
    ) -> [DayTotal] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { DayTotal(day: $0, seconds: totals[$0] ?? 0) }
        }
    }

    /// Columns of weeks (oldest first), each Monday to Sunday, ending with the current week.
    static func heatmapWeeks(weeks: Int, now: Date = .now, calendar: Calendar) -> [[Date]] {
        let current = weekDays(now: now, calendar: calendar)
        guard let monday = current.first else { return [] }
        return (0..<weeks).reversed().compactMap { back in
            calendar.date(byAdding: .weekOfYear, value: -back, to: monday).map { start in
                (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            }
        }
    }

    /// Practice time per genre (nil = 未分类), biggest first; genres with no time are left out.
    static func genreTotals(_ sessions: [PracticeSession]) -> [GenreShare] {
        let totals = sessions.reduce(into: [DanceGenre?: TimeInterval]()) { totals, session in
            totals[session.genre, default: 0] += session.duration
        }
        return totals
            .map { GenreShare(genre: $0.key, seconds: $0.value) }
            .sorted { a, b in
                // Ties fall back to the fixed genre order so the list doesn't shuffle.
                a.seconds != b.seconds ? a.seconds > b.seconds : genreOrder(a.genre) < genreOrder(b.genre)
            }
    }

    /// 未分类 sorts last.
    private static func genreOrder(_ genre: DanceGenre?) -> Int {
        genre.flatMap { DanceGenre.allCases.firstIndex(of: $0) } ?? DanceGenre.allCases.count
    }

    /// Heatmap shade 0...4 from fixed minute bands, so a cell means the same thing every week.
    static func heatLevel(_ seconds: TimeInterval) -> Int {
        switch seconds / 60 {
        case ..<1: 0
        case ..<15: 1
        case ..<30: 2
        case ..<60: 3
        default: 4
        }
    }
}
