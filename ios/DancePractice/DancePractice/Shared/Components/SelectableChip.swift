//
//  SelectableChip.swift
//  DancePractice
//

import SwiftUI

/// Capsule toggle used for genre filters and pickers. Selected = ink fill.
struct SelectableChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    /// Stretch to the available width, for chips laid out in a grid.
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Theme.onInk : Color.primary)
                .background(Capsule().fill(isSelected ? Theme.ink : Theme.surface))
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 0.5)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        SelectableChip(title: "All", isSelected: true) {}
        SelectableChip(title: "Kpop", isSelected: false) {}
        SelectableChip(title: "Jazz", isSelected: false) {}
    }
    .padding()
    .background(Theme.background)
}
