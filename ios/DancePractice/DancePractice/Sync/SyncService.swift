//
//  SyncService.swift
//  DancePractice
//

import Foundation
import Observation
import SwiftData

/// Keeps the signed-in account's store in step with the server through POST /api/sync.
///
/// One round: push everything flagged `needsSync` plus the deletion outbox, apply what the server
/// sends back, then clear the flags of what was pushed and save the new cursor. Only one sync runs
/// at a time (the client-side twin of the server's per-user lock); a request that arrives
/// meanwhile makes the running one go around once more.
@Observable
@MainActor
final class SyncService {
    enum Status: Equatable {
        case idle, syncing, failed
    }

    private(set) var status: Status = .idle
    /// For the signed-in account; nil until it has synced once on this device.
    private(set) var lastSyncedAt: Date?
    private(set) var errorMessage: String?

    /// The backend's SyncRequest limits; a fuller outbox goes up over several rounds.
    static let roomLimit = 500
    static let sessionLimit = 2000
    /// A guard against looping forever if the server kept answering without taking anything.
    private static let maxRounds = 20

    @ObservationIgnored private let accounts: AccountManager
    @ObservationIgnored private let stores: AccountStores
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var runsAgain = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    init(accounts: AccountManager, stores: AccountStores, defaults: UserDefaults = .standard) {
        self.accounts = accounts
        self.stores = stores
        self.defaults = defaults
    }

    /// Call when the signed-in account changes, so the screen shows that account's state.
    func accountDidChange() {
        lastSyncedAt = accounts.account.flatMap { defaults.object(forKey: Self.lastSyncedKey($0.id)) as? Date }
        errorMessage = nil
        if !isRunning {
            status = .idle
        }
    }

    /// Syncs a couple of seconds from now; calls in the meantime push the time back, so a burst of
    /// edits becomes one request.
    func requestSync() {
        guard accounts.account != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        guard accounts.account != nil else { return }
        guard !isRunning else {
            runsAgain = true
            return
        }
        isRunning = true
        status = .syncing
        defer { isRunning = false }

        repeat {
            runsAgain = false
            // Re-read each time: the account may have changed since the last round.
            guard let accountID = accounts.account?.id else { break }
            do {
                try await sync(accountID: accountID)
                let now = Date.now
                defaults.set(now, forKey: Self.lastSyncedKey(accountID))
                lastSyncedAt = now
                errorMessage = nil
                status = .idle
            } catch AccountError.switchedAccount {
                // The new account gets its own round.
                runsAgain = accounts.account != nil
            } catch {
                if accounts.account?.id == accountID {
                    errorMessage = error.localizedDescription
                    status = .failed
                }
            }
        } while runsAgain

        if status == .syncing {
            status = .idle
        }
    }

    /// Drops what this device remembers about an account's sync, after the account is deleted.
    func forget(accountID: UUID) {
        defaults.removeObject(forKey: Self.cursorKey(accountID))
        defaults.removeObject(forKey: Self.lastSyncedKey(accountID))
    }

    // MARK: One account

    private func sync(accountID: UUID) async throws {
        // Taken now, while this account is the current one, so the cached container is reused.
        let context = stores.container(for: accountID).mainContext
        var cursor = Int64(defaults.integer(forKey: Self.cursorKey(accountID)))

        for _ in 0..<Self.maxRounds {
            let outbox = try Outbox(context: context)
            let request = SyncRequestDTO(cursor: cursor, rooms: outbox.rooms, sessions: outbox.sessions.map(SessionDTO.init))
            let response: SyncResponseDTO = try await accounts.send(.post("/api/sync", json: request), as: accountID)

            try apply(response, pushedTombstones: Set(outbox.tombstones.map(\.roomID)), to: context)
            outbox.markPushed(in: context)
            try context.save()

            cursor = response.cursor
            defaults.set(Int(cursor), forKey: Self.cursorKey(accountID))
            if !outbox.isFull {
                return
            }
        }
    }

    private func apply(_ response: SyncResponseDTO, pushedTombstones: Set<UUID>, to context: ModelContext) throws {
        var rooms = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PracticeRoom>()).map { ($0.id, $0) })
        let tombstones = Set(try context.fetch(FetchDescriptor<DeletedRoom>()).map(\.roomID))

        for remote in response.rooms {
            let local: SyncMerger.Local
            if let room = rooms[remote.id] {
                local = .room(needsSync: room.needsSync, updatedAt: room.updatedAt)
            } else if tombstones.contains(remote.id) && !pushedTombstones.contains(remote.id) {
                local = .pendingDelete
            } else {
                // A tombstone pushed in this round that comes back alive lost to a newer edit: restore it.
                local = .none
            }

            switch SyncMerger.action(for: remote, local: local) {
            case .insert:
                let room = PracticeRoom(remote)
                context.insert(room)
                rooms[room.id] = room
            case .update:
                rooms[remote.id]?.apply(remote)
            case .delete:
                if let room = rooms.removeValue(forKey: remote.id) {
                    let fileNames = room.fileNames
                    context.delete(room)
                    fileNames.forEach(VideoFileStore.delete(fileName:))
                }
            case .keepLocal, .skip:
                break
            }
        }

        let sessionIDs = Set(try context.fetch(FetchDescriptor<PracticeSession>()).map(\.id))
        for remote in response.sessions where !sessionIDs.contains(remote.id) {
            context.insert(PracticeSession(remote, room: remote.roomId.flatMap { rooms[$0] }))
        }
    }

    private static func cursorKey(_ accountID: UUID) -> String {
        "sync.\(accountID.uuidString).cursor"
    }

    private static func lastSyncedKey(_ accountID: UUID) -> String {
        "sync.\(accountID.uuidString).lastSyncedAt"
    }
}

/// What one round pushes, read from the store just before the request.
@MainActor
private struct Outbox {
    let changedRooms: [(room: PracticeRoom, updatedAt: Date)]
    let tombstones: [DeletedRoom]
    let sessions: [PracticeSession]

    init(context: ModelContext) throws {
        var tombstones = FetchDescriptor<DeletedRoom>()
        tombstones.fetchLimit = SyncService.roomLimit
        self.tombstones = try context.fetch(tombstones)

        // A fetchLimit of 0 means "no limit", so a full batch of tombstones skips the fetch instead.
        let roomSpace = SyncService.roomLimit - self.tombstones.count
        var rooms = FetchDescriptor<PracticeRoom>(predicate: #Predicate { $0.needsSync == true })
        rooms.fetchLimit = roomSpace
        changedRooms = roomSpace > 0 ? try context.fetch(rooms).map { ($0, $0.updatedAt) } : []

        var sessions = FetchDescriptor<PracticeSession>(predicate: #Predicate { $0.needsSync == true })
        sessions.fetchLimit = SyncService.sessionLimit
        self.sessions = try context.fetch(sessions)
    }

    var rooms: [RoomDTO] {
        tombstones.compactMap(\.room) + changedRooms.map { RoomDTO($0.room) }
    }

    /// At a limit, so more may be waiting for another round.
    var isFull: Bool {
        tombstones.count + changedRooms.count >= SyncService.roomLimit || sessions.count >= SyncService.sessionLimit
    }

    func markPushed(in context: ModelContext) {
        for (room, pushedUpdatedAt) in changedRooms
        where !room.isDeleted && SyncMerger.isClean(afterPushing: pushedUpdatedAt, current: room.updatedAt) {
            room.needsSync = false
        }
        tombstones.forEach(context.delete)
        sessions.forEach { $0.needsSync = false }
    }
}
