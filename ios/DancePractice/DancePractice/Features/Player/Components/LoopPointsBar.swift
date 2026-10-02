//
//  LoopPointsBar.swift
//  DancePractice
//

import SwiftUI

/// "Set A" / "Set B" / clear controls for the A-B loop.
struct LoopPointsBar: View {
    let markA: Double?
    let markB: Double?
    let onSetA: () -> Void
    let onSetB: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            pointButton(letter: "A", time: markA, action: onSetA)
            pointButton(letter: "B", time: markB, action: onSetB)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
            }
            .buttonStyle(.plain)
            .disabled(markA == nil && markB == nil)
            .opacity(markA == nil && markB == nil ? 0.4 : 1)
            .accessibilityLabel("清除 A-B 点")
        }
    }

    private func pointButton(letter: String, time: Double?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ABMarker(letter: letter)
                Text(time.map(TimeFormat.precise) ?? "设为当前")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(time == nil ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("把当前时间设为 \(letter) 点")
    }
}
