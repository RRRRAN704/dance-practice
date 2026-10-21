//
//  GenreShareCard.swift
//  DancePractice
//

import Charts
import SwiftUI

/// Donut of practice time per genre, with a legend that spells out each share.
struct GenreShareCard: View {
    let shares: [GenreShare]

    private var total: TimeInterval { shares.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        SectionCard(title: "舞种占比") {
            HStack(spacing: 20) {
                Chart(shares) { share in
                    SectorMark(
                        angle: .value("时长", share.seconds),
                        innerRadius: .ratio(0.64),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(ChartPalette.color(for: share.genre))
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)
                .overlay {
                    VStack(spacing: 2) {
                        Text("总计")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(TimeFormat.practiceDuration(total))
                            .font(.subheadline.weight(.bold))
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 76)
                }

                // Names and percentages are always written out, so colour never carries the meaning alone.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(shares) { share in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ChartPalette.color(for: share.genre))
                                .frame(width: 9, height: 9)
                            Text(ChartPalette.genreName(share.genre))
                                .font(.subheadline)
                            Spacer(minLength: 4)
                            Text(percent(share))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func percent(_ share: GenreShare) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((share.seconds / total * 100).rounded()))%"
    }
}
