//
//  SyncMerger.swift
//  DancePractice
//

import Foundation

/// The sync decisions, kept free of SwiftData and networking so they can be unit-tested.
enum SyncMerger {
    /// What this device knows about a room the server sent back.
    enum Local: Equatable {
        case none
        case room(needsSync: Bool, updatedAt: Date)
        /// Deleted here, and the tombstone hasn't been pushed yet.
        case pendingDelete
    }

    enum RoomAction: Equatable {
        case insert, update, delete
        /// Edited here after the server's version; the local edit goes up on the next push.
        case keepLocal
        case skip
    }

    static func action(for remote: RoomDTO, local: Local) -> RoomAction {
        switch local {
        case .pendingDelete:
            // Our deletion still has to reach the server; it decides then.
            return .skip
        case .none:
            return remote.deletedAt == nil ? .insert : .skip
        case .room(let needsSync, let updatedAt):
            if remote.deletedAt != nil {
                // Deletions are final, like on the server.
                return .delete
            }
            if needsSync && APIDate.millis(updatedAt) > APIDate.millis(remote.updatedAt) {
                return .keepLocal
            }
            return .update
        }
    }

    /// After a push succeeds, a room is clean again only if nobody edited it while the request was
    /// in flight (and the server's version didn't replace it, which clears the flag already).
    static func isClean(afterPushing pushed: Date, current: Date) -> Bool {
        APIDate.millis(pushed) == APIDate.millis(current)
    }
}
