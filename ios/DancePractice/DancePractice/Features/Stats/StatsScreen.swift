//
//  StatsScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The Stats tab: totals, streaks, a daily trend, a 12-week heatmap and genre shares.
struct StatsScreen: View {
    @Query private var sessions: [PracticeSession]

    private let calendar = PracticeStats.calendar()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    totalsCard
                    streakCard
                    if sessions.isEmpty {
                        emptyCard
                    } else {
                        let totals = PracticeStats.totalsByDay(sessions, calendar: calendar)
                        TrendChartCard(totals: totals, calendar: calendar)
                        HeatmapCard(totals: totals, calendar: calendar)
                        GenreShareCard(shares: PracticeStats.genreTotals(sessions))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .navigationTitle("Practice Stats")
        }
    }

    private var totalsCard: some View {
        let today = TimeFormat.durationParts(PracticeStats.today(sessions, calendar: calendar))
        let week = TimeFormat.durationParts(PracticeStats.thisWeek(sessions, calendar: calendar))
        let month = TimeFormat.durationParts(PracticeStats.thisMonth(sessions, calendar: calendar))
        return HStack(spacing: 12) {
            StatValue(title: "Today", value: today.value, unit: today.unit)
            StatValue(title: "This Week", value: week.value, unit: week.unit)
            StatValue(title: "This Month", value: month.value, unit: month.unit)
        }
        .cardStyle(padding: 16)
    }

    private var streakCard: some View {
        let days = PracticeStats.practicedDays(sessions.map(\.startedAt), calendar: calendar)
        let all = TimeFormat.durationParts(sessions.reduce(0) { $0 + $1.duration })
        let current = PracticeStats.currentStreak(days: days, calendar: calendar)
        let longest = PracticeStats.longestStreak(days: days, calendar: calendar)
        return HStack(spacing: 12) {
            StatValue(title: "Current Streak", value: String(current), unit: TimeFormat.dayUnit(current))
            StatValue(title: "Longest Streak", value: String(longest), unit: TimeFormat.dayUnit(longest))
            StatValue(title: "All Time", value: all.value, unit: all.unit)
        }
        .cardStyle(padding: 16)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(Theme.accent)
            Text("No practice yet")
                .font(.headline)
            Text("Play a video in a practice room and your practice time will show up here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}

#Preview {
    StatsScreen()
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
