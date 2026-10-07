//
//  PlayButton.swift
//  DancePractice
//

import SwiftUI

/// Wide white "开始播放 / 暂停" button at the bottom of the player.
struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isPlaying ? "暂停" : "开始播放", systemImage: isPlaying ? "pause" : "play")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        PlayButton(isPlaying: false) {}
        PlayButton(isPlaying: true) {}
    }
    .padding()
    .background(Theme.playerBackground)
}
