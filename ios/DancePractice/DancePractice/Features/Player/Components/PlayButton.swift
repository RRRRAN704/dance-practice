//
//  PlayButton.swift
//  DancePractice
//

import SwiftUI

/// Wide white "Play / Pause" button at the bottom of the player.
/// Compact shows just the icon in a white circle, for the portrait fullscreen bar.
struct PlayButton: View {
    let isPlaying: Bool
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isCompact {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white))
            } else {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause" : "play")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(.white))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

#Preview {
    VStack {
        PlayButton(isPlaying: false) {}
        PlayButton(isPlaying: true) {}
        PlayButton(isPlaying: false, isCompact: true) {}
    }
    .padding()
    .background(Theme.playerBackground)
}
