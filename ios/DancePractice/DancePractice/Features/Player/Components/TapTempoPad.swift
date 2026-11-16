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
            HStack(spacing: 6) {
                ForEach(1...TapTempo.maximumTaps, id: \.self) { index in
                    Circle()
                        .fill(index <= tapCount ? Theme.accent : Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
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
            return "Those taps were uneven. Try again from 1"
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
