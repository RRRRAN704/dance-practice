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
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "figure.dance")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
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
