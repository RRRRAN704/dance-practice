//
//  Theme.swift
//  DancePractice
//

import SwiftUI

enum Theme {
    // MARK: Player (always dark)
    static let accent = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let playerBackground = Color(red: 0.06, green: 0.08, blue: 0.11)
    static let panel = Color.white.opacity(0.07)
    static let panelBorder = Color.white.opacity(0.12)

    // MARK: App screens (follow light/dark mode)
    /// Primary buttons and selected chips: black in light mode, white in dark mode.
    static let ink = Color(.label)
    /// Text and icons drawn on top of `ink`.
    static let onInk = Color(.systemBackground)
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let fieldFill = Color(.tertiarySystemFill)
    static let hairline = Color(.separator)

    static let cardRadius: CGFloat = 18
    static let fieldRadius: CGFloat = 14
}

extension View {
    /// White rounded card with a soft shadow; the shadow fades out in dark mode, where it wouldn't show.
    func cardStyle(padding: CGFloat = 12) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

private struct CardStyle: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, y: 4)
            )
    }
}
