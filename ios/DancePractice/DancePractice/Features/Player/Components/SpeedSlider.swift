//
//  SpeedSlider.swift
//  DancePractice
//

import SwiftUI

/// Speed slider with tappable reference marks.
/// Tap anywhere on the track to jump there, then keep dragging to fine-tune.
/// `speed` is only written when the finger lifts, so the player gets one rate change per gesture.
struct SpeedSlider: View {
    enum Style {
        /// Centred value in a rounded panel, for the regular player layout.
        case regular
        /// Small value label at the top-left, no panel, for the fullscreen control bar.
        case compact
    }

    @Binding var speed: Double
    var range: ClosedRange<Double> = 0.25...2.0
    var step: Double = 0.05
    var style: Style = .regular

    /// In-flight value while the finger is down; nil otherwise.
    @State private var dragValue: Double?

    private let marks: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]
    private let accessibilityStep: Double = 0.25
    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 6

    private var displayedSpeed: Double { dragValue ?? speed }

    var body: some View {
        VStack(alignment: style == .compact ? .leading : .center, spacing: style == .compact ? 0 : 4) {
            Text(Self.label(for: displayedSpeed))
                .font(style == .compact ? .subheadline.monospacedDigit() : .title3.weight(.semibold).monospacedDigit())

            track
                .frame(height: thumbSize + 8)

            GeometryReader { geo in
                ForEach(marks, id: \.self) { mark in
                    Button(Self.label(for: mark, suffix: "")) { speed = mark }
                        .buttonStyle(.plain)
                        .font(style == .compact ? .caption2.monospacedDigit() : .caption.monospacedDigit())
                        .foregroundStyle(abs(displayedSpeed - mark) < 0.001 ? .white : .secondary)
                        .position(x: x(for: mark, width: geo.size.width), y: geo.size.height / 2)
                }
            }
            .frame(height: 20)
        }
        .padding(style == .compact ? 0 : 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(style == .compact ? .clear : Theme.panel))
    }

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let midY = geo.size.height / 2
            let thumbX = x(for: displayedSpeed, width: width)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: width - thumbSize, height: trackHeight)
                    .position(x: width / 2, y: midY)

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(thumbX - thumbSize / 2, 0), height: trackHeight)
                    .position(x: (thumbSize / 2 + thumbX) / 2, y: midY)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(radius: 2)
                    .scaleEffect(dragValue == nil ? 1 : 1.15)
                    .position(x: thumbX, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragValue = self.value(for: value.location.x, width: width)
                    }
                    .onEnded { value in
                        speed = self.value(for: value.location.x, width: width)
                        dragValue = nil
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("速度")
        .accessibilityValue(Self.label(for: speed))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: speed = Self.snapped(speed + accessibilityStep, range: range, step: step)
            case .decrement: speed = Self.snapped(speed - accessibilityStep, range: range, step: step)
            @unknown default: break
            }
        }
    }

    /// Thumb centre for a value; marks use the same mapping so they line up exactly.
    private func x(for value: Double, width: CGFloat) -> CGFloat {
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return thumbSize / 2 + (width - thumbSize) * CGFloat(min(max(fraction, 0), 1))
    }

    private func value(for x: CGFloat, width: CGFloat) -> Double {
        let usable = width - thumbSize
        guard usable > 0 else { return speed }
        let fraction = Double((x - thumbSize / 2) / usable)
        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        return Self.snapped(raw, range: range, step: step)
    }

    /// Clamps to `range` and snaps to the nearest `step`.
    nonisolated static func snapped(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return (stepped * 100).rounded() / 100
    }

    /// 0.75 -> "0.75x", 1.0 -> "1x"
    static func label(for value: Double, suffix: String = "x") -> String {
        String(format: "%g", (value * 100).rounded() / 100) + suffix
    }
}

#Preview {
    @Previewable @State var speed = 0.75
    SpeedSlider(speed: $speed)
        .padding()
        .background(Theme.playerBackground)
        .preferredColorScheme(.dark)
}
