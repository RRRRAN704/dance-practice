//
//  RoomFilter.swift
//  DancePractice
//

/// Pure filtering for the rooms list, kept out of the view so it can be unit-tested.
enum RoomFilter {
    /// nil genre means "全部": every room, unchanged.
    static func rooms(_ rooms: [PracticeRoom], genre: DanceGenre?) -> [PracticeRoom] {
        guard let genre else { return rooms }
        return rooms.filter { $0.genre == genre }
    }
}
