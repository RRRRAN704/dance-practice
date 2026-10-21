//
//  TrendChartCard.swift
//  DancePractice
//

import Charts
import SwiftUI

/// Minutes practiced per day over the last 7 or 30 days. Tap or drag a bar to read its value.
struct TrendChartCard: View {
    enum Span: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        var id: Int { rawValue }
        var title: String { self == .week ? "近 7 天" : "近 30 天" }
    }

    let totals: [Date: TimeInterval]
    let calendar: Calendar

    @State private var span: Span = .week
    @State private var selectedDate: Date?

    private static let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        let days = PracticeStats.recentDays(totals, count: span.rawValue, calendar: calendar)
        let selected = selectedDate.flatMap { date in days.first { calendar.isDate($0.day, inSameDayAs: date) } }

        SectionCard(title: "练习时长趋势") {
            Picker("范围", selection: $span) {
                ForEach(Span.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        } content: {
            Chart {
                ForEach(days) { item in
                    BarMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("分钟", item.seconds / 60),
                        width: .ratio(span == .week ? 0.5 : 0.7)
                    )
                    .cornerRadius(4)
                    // Dim the other bars while one is selected.
                    .foregroundStyle(ChartPalette.bar.opacity(selected == nil || selected == item ? 1 : 0.3))
                }
                if let selected {
                    RuleMark(x: .value("日期", selected.day, unit: .day))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            callout(for: selected)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Theme.hairline.opacity(0.6))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: span == .week ? 1 : 7)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            }
            .frame(height: 180)
            .onChange(of: span) { selectedDate = nil }

            Text("单位：分钟")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func callout(for item: DayTotal) -> some View {
        VStack(spacing: 2) {
            Text(dayLabel(item.day))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(item.seconds > 0 ? TimeFormat.practiceDuration(item.seconds) : "没有练习")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface).shadow(color: .black.opacity(0.12), radius: 6, y: 2))
    }

    /// Chinese labels regardless of the device language: 一…日 for a week, 10/14 for a month.
    private func axisLabel(for date: Date) -> String {
        if span == .week {
            return Self.weekdayLabels[calendar.component(.weekday, from: date) - 1]
        }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private func dayLabel(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日 周\(Self.weekdayLabels[(parts.weekday ?? 1) - 1])"
    }
}
