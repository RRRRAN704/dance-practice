//
//  StatValue.swift
//  DancePractice
//

import SwiftUI

/// A small caption over a big number with its unit, e.g. Today / 45 min.
struct StatValue: View {
    let title: LocalizedStringResource
    /// Already formatted, e.g. "45" or "3.5".
    let value: String
    /// Already localized, e.g. "min" / "分钟".
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HStack {
        StatValue(title: "Today", value: "45", unit: "min")
        StatValue(title: "This Week", value: "3.5", unit: "h")
        StatValue(title: "Streak", value: "7", unit: "days")
    }
    .cardStyle(padding: 16)
    .padding()
    .background(Theme.background)
}
