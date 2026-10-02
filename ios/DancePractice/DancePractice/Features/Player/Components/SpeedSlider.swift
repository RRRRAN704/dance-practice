//
//  SpeedSlider.swift
//  DancePractice
//

import SwiftUI

/// Continuous speed slider with tappable reference marks.
struct SpeedSlider: View {
    @Binding var speed: Double
    var range: ClosedRange<Double> = 0.25...2.0
    var step: Double = 0.05

    private let marks: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2]
    /// Approximate inset of the system slider track, so marks line up with the thumb.
    private let trackInset: CGFloat = 14

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("速度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.label(for: speed))
                    .font(.title3.weight(.semibold).monospacedDigit())
            }

            Slider(value: $speed, in: range, step: step)
                .tint(Theme.accent)

            GeometryReader { geo in
                let usable = geo.size.width - trackInset * 2
                ForEach(marks, id: \.self) { mark in
                    let fraction = (mark - range.lowerBound) / (range.upperBound - range.lowerBound)
                    Button(Self.label(for: mark, suffix: "")) { speed = mark }
                        .buttonStyle(.plain)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(abs(speed - mark) < 0.001 ? .white : .secondary)
                        .position(x: trackInset + usable * fraction, y: geo.size.height / 2)
                }
            }
            .frame(height: 20)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel))
    }

    /// 0.75 -> "0.75x", 1.0 -> "1x"
    static func label(for value: Double, suffix: String = "x") -> String {
        String(format: "%g", (value * 100).rounded() / 100) + suffix
    }
}

#Preview {
    SpeedSlider(speed: .constant(0.75))
        .padding()
        .background(Theme.playerBackground)
        .preferredColorScheme(.dark)
}
