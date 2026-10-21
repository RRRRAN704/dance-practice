//
//  HeatmapCard.swift
//  DancePractice
//

import SwiftUI

/// Last 12 weeks, one column per week and one row per weekday; darker = more practice.
struct HeatmapCard: View {
    let totals: [Date: TimeInterval]
    let calendar: Calendar
    var now: Date = .now

    static let weeks = 12
    private static let rowLabels = ["一", "", "三", "", "五", "", "日"]
    private static let spacing: CGFloat = 4

    @State private var selectedDay: Date?

    var body: some View {
        let columns = PracticeStats.heatmapWeeks(weeks: Self.weeks, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)

        SectionCard(title: "每周练习热力图") {
            Text("近 \(Self.weeks) 周")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } content: {
            HStack(alignment: .top, spacing: Self.spacing) {
                VStack(spacing: Self.spacing) {
                    ForEach(Self.rowLabels.indices, id: \.self) { row in
                        Text(Self.rowLabels[row])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 14)

                ForEach(columns, id: \.first) { week in
                    VStack(spacing: Self.spacing) {
                        ForEach(week, id: \.self) { day in
                            cell(day: day, isFuture: day > today)
                        }
                    }
                }
            }

            HStack {
                Text(selectionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                legend
            }
        }
    }

    private func cell(day: Date, isFuture: Bool) -> some View {
        let seconds = totals[day] ?? 0
        let isSelected = selectedDay == day
        return RoundedRectangle(cornerRadius: 3)
            .fill(isFuture ? Color.clear : ChartPalette.heat(PracticeStats.heatLevel(seconds)))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isFuture else { return }
                selectedDay = isSelected ? nil : day
            }
            .accessibilityLabel(accessibilityText(day: day, seconds: seconds))
    }

    private var selectionText: String {
        guard let selectedDay else { return "点一个格子查看当天时长" }
        let parts = calendar.dateComponents([.month, .day], from: selectedDay)
        let seconds = totals[selectedDay] ?? 0
        let amount = seconds > 0 ? TimeFormat.practiceDuration(seconds) : "没有练习"
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日 · \(amount)"
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("少")
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(ChartPalette.heat(level))
                    .frame(width: 10, height: 10)
            }
            Text("多")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityLabel("颜色越深练得越多：1、15、30、60 分钟为分界")
    }

    private func accessibilityText(day: Date, seconds: TimeInterval) -> String {
        let parts = calendar.dateComponents([.month, .day], from: day)
        let amount = seconds > 0 ? TimeFormat.practiceDuration(seconds) : "没有练习"
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日，\(amount)"
    }
}
