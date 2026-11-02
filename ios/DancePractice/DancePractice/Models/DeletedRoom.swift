//
//  DeletedRoom.swift
//  DancePractice
//

import Foundation
import SwiftData

/// Outbox for a deleted room: the room itself is gone locally, but the server still has to hear
/// about the deletion. Removed once a sync has pushed it.
@Model
final class DeletedRoom {
    var roomID: UUID
    /// The room as a RoomDTO with `deletedAt` set; the server expects a full row even for a tombstone.
    var payload: Data

    init(room: PracticeRoom, now: Date = .now) {
        var dto = RoomDTO(room)
        let deletedAt = now.roundedToMilliseconds
        dto.updatedAt = deletedAt
        dto.deletedAt = deletedAt
        self.roomID = room.id
        // Encoding our own struct can't fail.
        self.payload = try! APIClient.encoder.encode(dto)
    }

    var room: RoomDTO? {
        try? APIClient.decoder.decode(RoomDTO.self, from: payload)
    }
}
