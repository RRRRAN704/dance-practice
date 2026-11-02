//
//  SyncDTOs.swift
//  DancePractice
//

import Foundation

/// Mirrors the backend's RoomDto.
struct RoomDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var artist: String?
    var genre: String?
    var note: String?
    /// The device that created the room's file name; other devices keep their own (see `PracticeRoom.fileNames`).
    var videoFileName: String
    var createdAt: Date
    var lastOpenedAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
}

/// Mirrors the backend's SessionDto.
struct SessionDTO: Codable, Equatable {
    var id: UUID
    var roomId: UUID?
    var roomName: String
    var genre: String?
    var startedAt: Date
    var durationSeconds: Double
}

struct SyncRequestDTO: Encodable {
    var cursor: Int64
    var rooms: [RoomDTO]
    var sessions: [SessionDTO]
}

struct SyncResponseDTO: Decodable {
    var cursor: Int64
    var rooms: [RoomDTO]
    var sessions: [SessionDTO]
}

extension RoomDTO {
    init(_ room: PracticeRoom) {
        self.init(id: room.id, name: room.name, artist: room.artist, genre: room.genreRaw, note: room.note,
                  videoFileName: room.videoFileName, createdAt: room.createdAt, lastOpenedAt: room.lastOpenedAt,
                  updatedAt: room.updatedAt, deletedAt: nil)
    }
}

extension SessionDTO {
    init(_ session: PracticeSession) {
        self.init(id: session.id, roomId: session.room?.id, roomName: session.roomName, genre: session.genreRaw,
                  startedAt: session.startedAt, durationSeconds: session.duration)
    }
}

extension PracticeRoom {
    /// A room first seen on another device. Its video isn't on this phone.
    convenience init(_ dto: RoomDTO) {
        self.init(name: dto.name, videoFileName: dto.videoFileName, createdAt: dto.createdAt)
        id = dto.id
        apply(dto)
    }

    /// Takes the server's details. The file names stay this device's own.
    func apply(_ dto: RoomDTO) {
        name = dto.name
        artist = dto.artist
        genreRaw = dto.genre
        note = dto.note
        createdAt = dto.createdAt
        // Opening isn't synced as an edit, so keep whichever side opened it last.
        lastOpenedAt = [lastOpenedAt, dto.lastOpenedAt].compactMap { $0 }.max()
        updatedAt = dto.updatedAt
        needsSync = false
    }
}

extension PracticeSession {
    /// A session logged on another device.
    convenience init(_ dto: SessionDTO, room: PracticeRoom?) {
        self.init(startedAt: dto.startedAt, duration: dto.durationSeconds, roomName: dto.roomName,
                  genreRaw: dto.genre, room: room)
        id = dto.id
        needsSync = false
    }
}
