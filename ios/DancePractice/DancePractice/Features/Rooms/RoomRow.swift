//
//  RoomRow.swift
//  DancePractice
//

import SwiftUI

/// One practice room in the list: cover, name and details.
struct RoomRow: View {
    let room: PracticeRoom

    var body: some View {
        HStack(spacing: 14) {
            CoverImage(url: room.coverURL)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(room.name)
                    .font(.system(.headline, weight: .bold))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Label(practiceSummary, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
        }
    }

    /// "Total 1.5 h · Last Today 20:12"
    private var practiceSummary: String {
        guard let last = room.lastPracticedAt else { return String(localized: "No practice yet") }
        return String(localized: "Total \(TimeFormat.practiceDuration(room.totalPracticeTime)) · Last \(TimeFormat.lastPracticed(last))")
    }

    /// "Artist · Genre", skipping whichever is missing.
    private var subtitle: String? {
        let parts = [room.artist, room.genre.map { String(localized: $0.displayName) }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        RoomRow(room: PracticeRoom(name: "Smoothie", videoFileName: "a.mov", artist: "NCT DREAM", genre: .kpop))
        RoomRow(room: PracticeRoom(name: "Untitled", videoFileName: "b.mov"))
    }
    .modelContainer(for: PracticeRoom.self, inMemory: true)
}
