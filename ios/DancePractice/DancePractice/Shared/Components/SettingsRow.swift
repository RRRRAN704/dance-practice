//
//  SettingsRow.swift
//  DancePractice
//

import SwiftUI

/// One row in a settings card: icon, title, an optional value on the right, and a chevron.
/// Disabled rows are dimmed and show their value (e.g. Coming soon) instead of a chevron.
struct SettingsRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    /// Already-localized text, e.g. a number or a status that the caller computed.
    var value: String?
    var showsChevron = true

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: 24)
                .foregroundStyle(Theme.ink)
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer()
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if showsChevron && isEnabled {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Stacks rows in one card with hairlines between them.
struct SettingsGroup<Content: View>: View {
    var title: LocalizedStringResource?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                // Group(subviews:) is iOS 18+, so dividers are placed by the caller via SettingsDivider.
                content
            }
            .cardStyle(padding: 0)
        }
    }
}

/// Hairline between rows, inset to line up with the titles.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }
}

#Preview {
    SettingsGroup(title: "Settings") {
        SettingsRow(title: "Dark Mode", systemImage: "moon", value: "System")
        SettingsDivider()
        SettingsRow(title: "Storage", systemImage: "internaldrive", value: "2.4 GB")
        SettingsDivider()
        SettingsRow(title: "Feedback", systemImage: "envelope", value: "Coming soon")
            .disabled(true)
    }
    .padding()
    .background(Theme.background)
}
