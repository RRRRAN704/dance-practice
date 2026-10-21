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

    /// "累计 1.5 小时 · 上次 今天 20:12"
    private var practiceSummary: String {
        guard let last = room.lastPracticedAt else { return "还没有练习记录" }
        return "累计 \(TimeFormat.practiceDuration(room.totalPracticeTime)) · 上次 \(TimeFormat.lastPracticed(last))"
    }

    /// "Artist · Genre", skipping whichever is missing.
    private var subtitle: String? {
        let parts = [room.artist, room.genre?.displayName].compactMap { $0 }
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
