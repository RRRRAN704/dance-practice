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
    @Environment(SyncService.self) private var sync: SyncService?
    @State private var hasVideo: Bool

    init(room: PracticeRoom) {
        self.room = room
        _hasVideo = State(initialValue: FileManager.default.fileExists(atPath: room.videoURL.path))
    }

    var body: some View {
        Group {
            if hasVideo {
                PlayerScreen(videoURL: room.videoURL, title: room.name) { record in
                    log(record)
                }
            } else {
                MissingVideoView(room: room) { hasVideo = true }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear { room.lastOpenedAt = .now }
    }

    private func log(_ record: PracticeRecord) {
        modelContext.insert(PracticeSession(startedAt: record.startedAt, duration: record.duration, room: room))
        // Saved right away: this often runs as the app goes to the background, where it may be killed.
        try? modelContext.save()
        sync?.requestSync()
    }
}
