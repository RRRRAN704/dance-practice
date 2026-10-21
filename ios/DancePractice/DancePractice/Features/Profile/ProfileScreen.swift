//
//  ProfileScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 我的 tab, guest version. Account features are listed but disabled until the backend exists.
struct ProfileScreen: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var usedBytes: Int64?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    guestCard

                    SettingsGroup(title: "账号与同步") {
                        SettingsRow(title: "云同步", systemImage: "icloud", value: "即将上线")
                            .disabled(true)
                        SettingsDivider()
                        SettingsRow(title: "导入游客数据", systemImage: "square.and.arrow.down", value: "即将上线")
                            .disabled(true)
                    }

                    SettingsGroup(title: "设置") {
                        appearanceMenu
                        SettingsDivider()
                        NavigationLink {
                            StorageScreen()
                        } label: {
                            SettingsRow(
                                title: "存储空间",
                                systemImage: "internaldrive",
                                value: usedBytes.map(StorageUsage.format)
                            )
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        SettingsRow(title: "意见反馈", systemImage: "envelope", value: "即将上线")
                            .disabled(true)
                        SettingsDivider()
                        NavigationLink {
                            AboutScreen()
                        } label: {
                            SettingsRow(title: "关于", systemImage: "info.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .navigationTitle("我的")
            // Refreshed on every return, e.g. after cleaning up on the storage screen.
            .onAppear {
                usedBytes = VideoFileStore.fileSizes().values.reduce(0, +)
            }
        }
    }

    private var guestCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.fieldFill))

            VStack(alignment: .leading, spacing: 4) {
                Text("游客")
                    .font(.title3.weight(.bold))
                Text("数据仅保存在本机")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("登录即将上线")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.fieldFill))
        }
        .cardStyle(padding: 16)
    }

    private var appearanceMenu: some View {
        Menu {
            Picker("深色模式", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        } label: {
            SettingsRow(title: "深色模式", systemImage: "moon", value: appearance.displayName)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileScreen()
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
