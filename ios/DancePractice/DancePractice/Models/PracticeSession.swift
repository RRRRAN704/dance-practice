//
//  PracticeSession.swift
//  DancePractice
//

import Foundation
import SwiftData

/// One logged stretch of practice. Feeds room totals, Home and Stats.
@Model
final class PracticeSession {
    var id: UUID
    var startedAt: Date
    /// Seconds of actual playback.
    var duration: TimeInterval
    /// nil once the room is deleted; the session is kept so history totals don't shrink.
    var room: PracticeRoom?
    /// Snapshots taken when logged, so a deleted room's sessions still have a name and genre.
    var roomName: String
    var genreRaw: String?
    /// Logged here and not pushed yet. Sessions never change, so once pushed they stay clean.
    var needsSync: Bool = true

    convenience init(startedAt: Date, duration: TimeInterval, room: PracticeRoom) {
        self.init(startedAt: startedAt, duration: duration, roomName: room.name, genreRaw: room.genreRaw, room: room)
    }

    init(startedAt: Date, duration: TimeInterval, roomName: String, genreRaw: String?, room: PracticeRoom?) {
        self.id = UUID()
        self.startedAt = startedAt
        self.duration = duration
        self.room = room
        self.roomName = roomName
        self.genreRaw = genreRaw
    }

    /// The room's current genre if it still exists (it may have been set later), else the snapshot.
    var genre: DanceGenre? {
        (room?.genreRaw ?? genreRaw).flatMap(DanceGenre.init(rawValue:))
    }
}
