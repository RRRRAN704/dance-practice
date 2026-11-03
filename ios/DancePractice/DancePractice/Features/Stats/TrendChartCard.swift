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
        var title: LocalizedStringResource { self == .week ? "7 Days" : "30 Days" }
    }

    let totals: [Date: TimeInterval]
    let calendar: Calendar

    @State private var span: Span = .week
    @State private var selectedDate: Date?

    var body: some View {
        let days = PracticeStats.recentDays(totals, count: span.rawValue, calendar: calendar)
        let selected = selectedDate.flatMap { date in days.first { calendar.isDate($0.day, inSameDayAs: date) } }

        SectionCard(title: "Practice Trend") {
            Picker("Range", selection: $span) {
                ForEach(Span.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        } content: {
            Chart {
                ForEach(days) { item in
                    BarMark(
                        x: .value("Date", item.day, unit: .day),
                        y: .value("Minutes", item.seconds / 60),
                        width: .ratio(span == .week ? 0.5 : 0.7)
                    )
                    .cornerRadius(4)
                    // Dim the other bars while one is selected.
                    .foregroundStyle(ChartPalette.bar.opacity(selected == nil || selected == item ? 1 : 0.3))
                }
                if let selected {
                    RuleMark(x: .value("Date", selected.day, unit: .day))
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

            Text("Unit: minutes")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func callout(for item: DayTotal) -> some View {
        VStack(spacing: 2) {
            Text(dayLabel(item.day))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(item.seconds > 0 ? TimeFormat.practiceDuration(item.seconds) : String(localized: "No practice"))
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface).shadow(color: .black.opacity(0.12), radius: 6, y: 2))
    }

    /// In the device language: weekday initials for a week ("M" / "一"), month/day for a month ("10/14").
    private func axisLabel(for date: Date) -> String {
        if span == .week {
            return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private func dayLabel(_ date: Date) -> String {
        TimeFormat.monthDayWeekday(date, calendar: calendar)
    }
}
