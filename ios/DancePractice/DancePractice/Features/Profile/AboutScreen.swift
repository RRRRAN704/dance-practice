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
        return "版本 \(short) (\(build))"
    }

    private static let features = [
        ("speedometer", "0.25x–2.0x 无级变速"),
        ("arrow.left.and.right.righttriangle.left.righttriangle.right", "一键镜面"),
        ("repeat", "A-B 循环练习片段"),
        ("film.stack", "缩略图时间轴"),
        ("chart.bar", "练习时长自动统计"),
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
                    Text("一个专属于舞蹈爱好者的扒舞练习工具")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 16)

                SettingsGroup(title: "功能") {
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
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutScreen() }
}
