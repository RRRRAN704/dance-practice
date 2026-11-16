//
//  TapTempoPad.swift
//  DancePractice
//

import SwiftUI

/// Covers the video while the user taps along with the music. The whole area is the tap target.
struct TapTempoPad: View {
    let tapCount: Int
    let isUneven: Bool
    let isPlaying: Bool
    /// Correcting an existing count's tempo rather than starting a new one.
    var isCalibrating = false
    let onTap: () -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    /// A tap counts when the finger lands, not when it lifts: landing is what lines up with the beat.
    @State private var isPressing = false

    var body: some View {
        ZStack {
            tapArea
            VStack {
                Spacer(minLength: 0)
                buttons
            }
            .padding(12)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    private var tapArea: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.title)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            // One row per eight. The second row is optional: more taps, steadier tempo.
            VStack(spacing: 6) {
                ForEach(0..<TapTempo.maximumTaps / BeatGrid.countsPerEight, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(1...BeatGrid.countsPerEight, id: \.self) { column in
                            let index = row * BeatGrid.countsPerEight + column
                            Circle()
                                .fill(index <= tapCount ? Theme.accent : Color.white.opacity(row == 0 ? 0.3 : 0.15))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.45))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressing else { return }
                    isPressing = true
                    onTap()
                }
                .onEnded { _ in isPressing = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
    }

    private var message: LocalizedStringResource {
        if !isPlaying {
            return "Play the video, then tap along"
        }
        if isUneven {
            return isCalibrating
                ? "Those taps didn't match the count. Try again from a 1"
                : "Those taps were uneven. Try again from 1"
        }
        if isCalibrating {
            return "Tap along from any 1 to fine-tune the tempo"
        }
        return "Tap anywhere on the beat, starting from 1"
    }

    private var buttons: some View {
        HStack {
            Button("Cancel", action: onCancel)
            Spacer()
            Button("Done", action: onDone)
                .disabled(tapCount < TapTempo.minimumTaps)
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .tint(.white)
    }
}

#Preview {
    TapTempoPad(tapCount: 5, isUneven: false, isPlaying: true, onTap: {}, onDone: {}, onCancel: {})
        .frame(height: 240)
        .background(Color.gray)
        .foregroundStyle(.white)
}
