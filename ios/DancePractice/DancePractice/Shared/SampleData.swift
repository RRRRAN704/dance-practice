//
//  SampleData.swift
//  DancePractice
//

#if DEBUG
import Foundation
import SwiftData

/// Debug-only demo data, so charts can be checked without weeks of real practice.
/// Launch with the `-sampleData` argument: the app then uses an in-memory store, leaving real data untouched.
enum SampleData {
    static let launchArgument = "-sampleData"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: AccountStores.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        seed(container.mainContext)
        return container
    }

    /// Rooms have no video files, so opening one shows the player's load error.
    @MainActor
    static func seed(_ context: ModelContext, now: Date = .now) {
        let rooms = [
            PracticeRoom(name: "Smoothie", videoFileName: "missing.mov", artist: "NCT DREAM", genre: .kpop),
            PracticeRoom(name: "Supernova", videoFileName: "missing.mov", artist: "aespa", genre: .kpop),
            PracticeRoom(name: "Jazz Walk", videoFileName: "missing.mov", genre: .jazz),
            PracticeRoom(name: "Krump Basics", videoFileName: "missing.mov", genre: .hiphop),
            PracticeRoom(name: "Urban Choreo", videoFileName: "missing.mov", artist: "Studio", genre: .urban),
            PracticeRoom(name: "Untitled", videoFileName: "missing.mov"),
        ]
        rooms.forEach(context.insert)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        // A fixed pattern instead of random numbers, so every launch looks the same.
        for back in 0..<84 {
            let pattern = (back * 37 + 11) % 10
            guard pattern < 7, let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            let room = rooms[(back + pattern) % rooms.count]
            let minutes = 8 + (pattern * 13 + back) % 70
            let start = day.addingTimeInterval(TimeInterval(18 * 3600 + pattern * 600))
            context.insert(PracticeSession(startedAt: min(start, now), duration: TimeInterval(minutes * 60), room: room))
        }
    }
}
#endif
