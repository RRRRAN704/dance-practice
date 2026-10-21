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
    var createdAt: Date
    /// Drives "recent rooms" on Home.
    var lastOpenedAt: Date?

    init(
        name: String,
        videoFileName: String,
        artist: String? = nil,
        genre: DanceGenre? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.videoFileName = videoFileName
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
}
