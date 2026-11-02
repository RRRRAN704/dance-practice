//
//  PrimaryButton.swift
//  DancePractice
//

import SwiftUI

/// Full-width ink capsule for the main action on a screen.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PrimaryButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

/// PrimaryButton's look on its own, for controls that aren't a Button, like a PhotosPicker.
struct PrimaryButtonLabel: View {
    let title: String
    var systemImage: String?

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .foregroundStyle(Theme.onInk)
        .background(Capsule().fill(Theme.ink))
        .opacity(isEnabled ? 1 : 0.3)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "创建练习室") {}
        PrimaryButton(title: "创建练习室", systemImage: "plus") {}
        PrimaryButton(title: "保存修改") {}
            .disabled(true)
    }
    .padding()
}
