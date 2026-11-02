//
//  AccountStores.swift
//  DancePractice
//

import Foundation
import SwiftData

/// Guest data and each account's data live in separate SwiftData stores, so signing in on a
/// shared phone never mixes anyone's rooms. Signing out keeps the account's store on the device,
/// so its data is there again (even offline) on the next login.
///
/// Video files stay in one shared folder (`VideoFileStore`); each file belongs to exactly one
/// store's room, which is why cleanup has to look at every store.
@MainActor
final class AccountStores {
    private var current: (accountID: UUID?, container: ModelContainer)?

    /// The container for an account, or the guest store for nil. Reused while the account stays the same.
    func container(for accountID: UUID?) -> ModelContainer {
        if let current, current.accountID == accountID {
            return current.container
        }
        let container = Self.makeContainer(for: accountID)
        current = (accountID, container)
        return container
    }

    private static func makeContainer(for accountID: UUID?) -> ModelContainer {
        #if DEBUG
        if SampleData.isRequested {
            return SampleData.makeContainer()
        }
        #endif
        if accountID != nil {
            try? FileManager.default.createDirectory(at: accountsDirectory, withIntermediateDirectories: true)
        }
        // Crashes like `.modelContainer(for:)` does if the store can't be opened.
        return try! ModelContainer(for: PracticeRoom.self, PracticeSession.self,
                                   configurations: ModelConfiguration(url: storeURL(for: accountID)))
    }

    /// nil is the guest store: SwiftData's default file, so data from before accounts existed is kept.
    static func storeURL(for accountID: UUID?) -> URL {
        guard let accountID else { return ModelConfiguration().url }
        return accountsDirectory.appending(path: "\(accountID.uuidString).store")
    }

    /// Accounts that have a store on this device.
    static func accountIDsOnDevice() -> [UUID] {
        let files = (try? FileManager.default.contentsOfDirectory(at: accountsDirectory,
                                                                  includingPropertiesForKeys: nil)) ?? []
        // SQLite keeps -shm and -wal files next to each store; only the .store itself counts.
        return files
            .filter { $0.pathExtension == "store" }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
    }

    /// File names used by rooms in every store on the device except the one in use.
    /// Returns nil if any store can't be read, so callers never treat its files as unused.
    static func fileNamesInOtherStores(than accountID: UUID?) -> Set<String>? {
        var skipped: URL? = storeURL(for: accountID)
        #if DEBUG
        // The sample store lives in memory, so every store on disk is "other".
        if SampleData.isRequested { skipped = nil }
        #endif

        let urls = ([nil] + accountIDsOnDevice()).map(storeURL(for:))
        var fileNames = Set<String>()
        for url in urls where url != skipped && FileManager.default.fileExists(atPath: url.path) {
            guard let container = try? ModelContainer(for: PracticeRoom.self, PracticeSession.self,
                                                      configurations: ModelConfiguration(url: url)),
                  let rooms = try? ModelContext(container).fetch(FetchDescriptor<PracticeRoom>())
            else { return nil }
            fileNames.formUnion(rooms.flatMap(\.fileNames))
        }
        return fileNames
    }

    private static var accountsDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Accounts", directoryHint: .isDirectory)
    }
}
