//
//  GenreFilterBar.swift
//  DancePractice
//

import SwiftUI

/// Horizontal chips: All plus every genre. nil selection means All.
struct GenreFilterBar: View {
    @Binding var selection: DanceGenre?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectableChip(title: "All", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(DanceGenre.allCases) { genre in
                    SelectableChip(title: genre.displayName, isSelected: selection == genre) {
                        selection = genre
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    @Previewable @State var selection: DanceGenre? = .kpop
    GenreFilterBar(selection: $selection)
        .background(Theme.background)
}
