//
//  StatValue.swift
//  DancePractice
//

import SwiftUI

/// A small caption over a big number with its unit, e.g. 今日练习 / 45 分钟.
struct StatValue: View {
    let title: String
    let value: String
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
        StatValue(title: "今日练习", value: "45", unit: "分钟")
        StatValue(title: "本周练习", value: "3.5", unit: "小时")
        StatValue(title: "连续练习", value: "7", unit: "天")
    }
    .cardStyle(padding: 16)
    .padding()
    .background(Theme.background)
}
