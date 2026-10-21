//
//  RoomPlayerScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The player opened from a room: plays its video and logs practice time to it.
/// Home's "continue" will reuse this, so the logging lives in one place.
struct RoomPlayerScreen: View {
    let room: PracticeRoom

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        PlayerScreen(videoURL: room.videoURL, title: room.name) { record in
            log(record)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear { room.lastOpenedAt = .now }
    }

    private func log(_ record: PracticeRecord) {
        modelContext.insert(PracticeSession(startedAt: record.startedAt, duration: record.duration, room: room))
        // Saved right away: this often runs as the app goes to the background, where it may be killed.
        try? modelContext.save()
    }
}
