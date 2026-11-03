//
//  AboutScreen.swift
//  DancePractice
//

import SwiftUI

/// App name, version and a short description.
struct AboutScreen: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(short) (\(build))")
    }

    private static let features: [(String, LocalizedStringResource)] = [
        ("speedometer", "Any speed from 0.25x to 2.0x"),
        ("arrow.left.and.right.righttriangle.left.righttriangle.right", "One-tap mirroring"),
        ("repeat", "A-B loops for tricky sections"),
        ("film.stack", "Thumbnail timeline"),
        ("chart.bar", "Automatic practice tracking"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "figure.dance")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.onInk)
                        .frame(width: 88, height: 88)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.ink))
                    Text("Dance Practice")
                        .font(.title2.weight(.bold))
                    Text(version)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("A practice tool for dancers learning choreography from videos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 16)

                SettingsGroup(title: "Features") {
                    ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                        if index > 0 { SettingsDivider() }
                        SettingsRow(title: feature.1, systemImage: feature.0, showsChevron: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutScreen() }
}
