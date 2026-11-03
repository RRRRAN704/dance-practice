//
//  RecentRoomRow.swift
//  DancePractice
//

import SwiftUI

/// A recent room on Home: cover, name, last practised, and a play badge.
struct RecentRoomRow: View {
    let room: PracticeRoom

    var body: some View {
        HStack(spacing: 14) {
            CoverImage(url: room.coverURL)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(room.name)
                    .font(.system(.headline, weight: .bold))
                    .lineLimit(1)
                if let artist = room.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(lastPracticedText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "play.fill")
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .cardStyle()
        .contentShape(Rectangle())
    }

    private var lastPracticedText: String {
        guard let last = room.lastPracticedAt else { return String(localized: "No practice yet") }
        return String(localized: "Last practiced: \(TimeFormat.lastPracticed(last))")
    }
}
