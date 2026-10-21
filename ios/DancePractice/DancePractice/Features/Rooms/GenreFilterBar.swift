//
//  GenreFilterBar.swift
//  DancePractice
//

import SwiftUI

/// Horizontal chips: 全部 plus every genre. nil selection means 全部.
struct GenreFilterBar: View {
    @Binding var selection: DanceGenre?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("全部", genre: nil)
                ForEach(DanceGenre.allCases) { genre in
                    chip(genre.displayName, genre: genre)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, genre: DanceGenre?) -> some View {
        let isSelected = selection == genre
        return Button {
            selection = genre
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(Capsule().fill(isSelected ? Theme.accent : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: DanceGenre? = .kpop
    GenreFilterBar(selection: $selection)
}
