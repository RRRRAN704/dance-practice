//
//  StatsScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 统计 tab: totals, streaks, a daily trend, a 12-week heatmap and genre shares.
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
            .navigationTitle("练习统计")
        }
    }

    private var totalsCard: some View {
        let today = TimeFormat.durationParts(PracticeStats.today(sessions, calendar: calendar))
        let week = TimeFormat.durationParts(PracticeStats.thisWeek(sessions, calendar: calendar))
        let month = TimeFormat.durationParts(PracticeStats.thisMonth(sessions, calendar: calendar))
        return HStack(spacing: 12) {
            StatValue(title: "今日练习", value: today.value, unit: today.unit)
            StatValue(title: "本周练习", value: week.value, unit: week.unit)
            StatValue(title: "本月练习", value: month.value, unit: month.unit)
        }
        .cardStyle(padding: 16)
    }

    private var streakCard: some View {
        let days = PracticeStats.practicedDays(sessions.map(\.startedAt), calendar: calendar)
        let all = TimeFormat.durationParts(sessions.reduce(0) { $0 + $1.duration })
        return HStack(spacing: 12) {
            StatValue(title: "连续练习", value: String(PracticeStats.currentStreak(days: days, calendar: calendar)), unit: "天")
            StatValue(title: "历史最长", value: String(PracticeStats.longestStreak(days: days, calendar: calendar)), unit: "天")
            StatValue(title: "累计练习", value: all.value, unit: all.unit)
        }
        .cardStyle(padding: 16)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(Theme.accent)
            Text("还没有练习数据")
                .font(.headline)
            Text("在练习室里播放视频，练习时长会自动记录在这里")
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
