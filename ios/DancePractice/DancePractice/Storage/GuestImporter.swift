//
//  GuestImporter.swift
//  DancePractice
//

import CryptoKit
import Foundation
import SwiftData

/// Copies the guest store's rooms and sessions into a signed-in account's store.
///
/// Create-or-update only, never delete: the guest data stays as it is, and importing again just
/// brings over what changed. Imported rows get ids derived from (account, guest id) rather than the
/// guest ids themselves, so a second import finds the same rows, and importing the same guest data
/// into two accounts doesn't hit the server's "id already in use" 409.
@MainActor
enum GuestImporter {
    struct Summary: Equatable {
        var rooms = 0
        var sessions = 0

        var isEmpty: Bool { rooms == 0 && sessions == 0 }
    }

    /// What the guest store on this device holds; empty if there is none.
    static func guestSummary() -> Summary {
        guard let context = guestContext() else { return Summary() }
        return Summary(rooms: (try? context.fetchCount(FetchDescriptor<PracticeRoom>())) ?? 0,
                       sessions: (try? context.fetchCount(FetchDescriptor<PracticeSession>())) ?? 0)
    }

    static func importGuestData(into context: ModelContext, accountID: UUID) throws -> Summary {
        guard let guest = guestContext() else { return Summary() }
        return try importData(from: guest, into: context, accountID: accountID)
    }

    /// The import itself, on any two contexts so tests can use in-memory stores.
    /// - Returns: how many rooms and sessions were new to the account.
    static func importData(from guest: ModelContext, into account: ModelContext, accountID: UUID) throws -> Summary {
        var imported = Summary()
        let accountRooms = try account.fetch(FetchDescriptor<PracticeRoom>())
        var roomsByID = Dictionary(uniqueKeysWithValues: accountRooms.map { ($0.id, $0) })

        for source in try guest.fetch(FetchDescriptor<PracticeRoom>()) {
            let id = importedID(source.id, accountID: accountID)
            if let room = roomsByID[id] {
                // Imported before: take guest edits made since, keep the account's own later edits.
                if APIDate.millis(source.updatedAt) > APIDate.millis(room.updatedAt) {
                    room.name = source.name
                    room.artist = source.artist
                    room.genreRaw = source.genreRaw
                    room.note = source.note
                    room.markEdited()
                }
                continue
            }
            let room = PracticeRoom(
                name: source.name,
                // Its own name for the file, so deleting either room never takes the other's video.
                // If the guest's video is gone, the made-up name shows "视频不在本机" in the player.
                videoFileName: VideoFileStore.duplicate(fileName: source.videoFileName) ?? "\(UUID().uuidString).mov",
                coverFileName: source.coverFileName.flatMap(VideoFileStore.duplicate(fileName:)),
                artist: source.artist,
                note: source.note,
                createdAt: source.createdAt)
            room.id = id
            room.genreRaw = source.genreRaw
            room.lastOpenedAt = source.lastOpenedAt
            account.insert(room)
            roomsByID[id] = room
            imported.rooms += 1
        }

        let sessionIDs = Set(try account.fetch(FetchDescriptor<PracticeSession>()).map(\.id))
        for source in try guest.fetch(FetchDescriptor<PracticeSession>()) {
            let id = importedID(source.id, accountID: accountID)
            guard !sessionIDs.contains(id) else { continue }
            let session = PracticeSession(
                startedAt: source.startedAt, duration: source.duration,
                roomName: source.roomName, genreRaw: source.genreRaw,
                room: source.room.flatMap { roomsByID[importedID($0.id, accountID: accountID)] })
            session.id = id
            account.insert(session)
            imported.sessions += 1
        }

        try account.save()
        return imported
    }

    /// The same guest row always maps to the same id within one account, and to different ids in
    /// different accounts. A SHA-256 of both ids, cut to 128 bits and marked as a version 8 UUID.
    nonisolated static func importedID(_ guestID: UUID, accountID: UUID) -> UUID {
        var input = Data()
        withUnsafeBytes(of: accountID.uuid) { input.append(contentsOf: $0) }
        withUnsafeBytes(of: guestID.uuid) { input.append(contentsOf: $0) }
        var bytes = Array(SHA256.hash(data: input).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// A context on the guest store, opened separately because the app is using the account's.
    private static func guestContext() -> ModelContext? {
        let url = AccountStores.storeURL(for: nil)
        guard FileManager.default.fileExists(atPath: url.path),
              let container = try? ModelContainer(for: AccountStores.schema, configurations: ModelConfiguration(url: url))
        else { return nil }
        return ModelContext(container)
    }
}
