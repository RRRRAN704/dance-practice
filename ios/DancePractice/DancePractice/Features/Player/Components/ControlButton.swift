//
//  ControlButton.swift
//  DancePractice
//

import SwiftUI

/// Toggle-style button used for mirror / A-B loop / metronome.
struct ControlButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    var isActive = false
    /// False shows just the icon, for narrow layouts.
    var showsTitle = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
                .labelStyle(TitleOrIconLabelStyle(showsTitle: showsTitle))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(isActive ? Theme.accent : .white)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Theme.accent : Theme.panelBorder, lineWidth: isActive ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(Text(title))
    }
}

private struct TitleOrIconLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        if showsTitle {
            Label(configuration)
        } else {
            configuration.icon
        }
    }
}

#Preview {
    HStack {
        ControlButton(title: "Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {}
        ControlButton(title: "A-B Loop", systemImage: "repeat", isActive: true) {}
    }
    .padding()
    .background(Theme.playerBackground)
}
