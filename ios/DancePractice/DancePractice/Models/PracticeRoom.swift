//
//  PracticeRoom.swift
//  DancePractice
//

import Foundation
import SwiftData

/// One song being learned: a single imported video plus its details.
@Model
final class PracticeRoom {
    var id: UUID
    var name: String
    var artist: String?
    /// Stored as a String so SwiftData doesn't depend on the enum's layout; use `genre`.
    var genreRaw: String?
    var note: String?
    /// File name inside VideoFileStore, not a full path: the sandbox path changes between installs.
    var videoFileName: String
    /// JPEG in VideoFileStore; nil if the frame couldn't be decoded.
    var coverFileName: String?
    var createdAt: Date
    /// Drives "recent rooms" on Home.
    var lastOpenedAt: Date?
    /// Deleting the room keeps its sessions (they just lose the link).
    @Relationship(deleteRule: .nullify, inverse: \PracticeSession.room)
    var sessions: [PracticeSession] = []

    init(
        name: String,
        videoFileName: String,
        coverFileName: String? = nil,
        artist: String? = nil,
        genre: DanceGenre? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.videoFileName = videoFileName
        self.coverFileName = coverFileName
        self.artist = artist
        self.genreRaw = genre?.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    var genre: DanceGenre? {
        get { genreRaw.flatMap(DanceGenre.init(rawValue:)) }
        set { genreRaw = newValue?.rawValue }
    }

    var videoURL: URL { VideoFileStore.url(for: videoFileName) }

    var coverURL: URL? { coverFileName.map(VideoFileStore.url(for:)) }

    var totalPracticeTime: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }

    var lastPracticedAt: Date? { sessions.map(\.startedAt).max() }

    /// Latest of practising, opening or creating; orders Home's recent rooms.
    var lastActivityAt: Date {
        [lastPracticedAt, lastOpenedAt, createdAt].compactMap { $0 }.max() ?? createdAt
    }

    /// Every file this room owns, for cleanup on delete.
    var fileNames: [String] { [videoFileName, coverFileName].compactMap { $0 } }
}
