//
//  PracticeSummaryCard.swift
//  DancePractice
//

import SwiftUI

/// Today / this week / streak, plus a Monday-to-Sunday row marking practiced days.
struct PracticeSummaryCard: View {
    let sessions: [PracticeSession]
    var now: Date = .now

    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private let calendar = PracticeStats.calendar()

    var body: some View {
        let days = PracticeStats.practicedDays(sessions.map(\.startedAt), calendar: calendar)
        let today = TimeFormat.durationParts(PracticeStats.today(sessions, now: now, calendar: calendar))
        let week = TimeFormat.durationParts(PracticeStats.thisWeek(sessions, now: now, calendar: calendar))
        let streak = PracticeStats.currentStreak(days: days, now: now, calendar: calendar)

        VStack(spacing: 18) {
            HStack(spacing: 12) {
                StatValue(title: "今日练习", value: today.value, unit: today.unit)
                divider
                StatValue(title: "本周练习", value: week.value, unit: week.unit)
                divider
                StatValue(title: "连续练习", value: String(streak), unit: "天")
            }

            HStack {
                ForEach(Array(PracticeStats.weekDays(now: now, calendar: calendar).enumerated()), id: \.offset) { index, day in
                    dayDot(label: Self.weekdayLabels[index], day: day, practiced: days.contains(day))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle(padding: 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 0.5, height: 36)
    }

    private func dayDot(label: String, day: Date, practiced: Bool) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: now)
        return VStack(spacing: 6) {
            Circle()
                .fill(practiced ? Theme.accent : Theme.fieldFill)
                .frame(width: 18, height: 18)
                .overlay {
                    // Ring today when it isn't filled yet, as a nudge.
                    if isToday && !practiced {
                        Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                    }
                }
            Text(label)
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("周\(label)\(practiced ? "，已练习" : "")")
    }
}
