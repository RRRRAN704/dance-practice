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
    private static let spacing: CGFloat = 4

    @State private var selectedDay: Date?

    var body: some View {
        let columns = PracticeStats.heatmapWeeks(weeks: Self.weeks, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        // Label every other row (Mon, Wed, Fri, Sun) so the column stays readable.
        let rowLabels = TimeFormat.mondayFirstWeekdays(calendar: calendar).short.enumerated().map { $0.offset.isMultiple(of: 2) ? $0.element : "" }

        SectionCard(title: "Weekly Heatmap") {
            Text("Last \(Self.weeks) Weeks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } content: {
            HStack(alignment: .top, spacing: Self.spacing) {
                VStack(spacing: Self.spacing) {
                    ForEach(rowLabels.indices, id: \.self) { row in
                        Text(rowLabels[row])
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
        guard let selectedDay else { return String(localized: "Tap a square to see that day") }
        return "\(TimeFormat.monthDay(selectedDay, calendar: calendar)) · \(amountText(totals[selectedDay] ?? 0))"
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("Less")
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(ChartPalette.heat(level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Darker means more practice. Steps at 1, 15, 30 and 60 minutes.")
    }

    private func accessibilityText(day: Date, seconds: TimeInterval) -> String {
        "\(TimeFormat.monthDay(day, calendar: calendar)), \(amountText(seconds))"
    }

    private func amountText(_ seconds: TimeInterval) -> String {
        seconds > 0 ? TimeFormat.practiceDuration(seconds) : String(localized: "No practice")
    }
}
