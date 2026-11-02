//
//  ProfileScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 我的 tab. Login works; sync and guest import are still disabled until they are built.
struct ProfileScreen: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(AccountManager.self) private var accounts
    @State private var usedBytes: Int64?
    @State private var showsAuthSheet = false
    @State private var confirmsLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    accountCard

                    SettingsGroup(title: "账号与同步") {
                        SettingsRow(title: "云同步", systemImage: "icloud", value: "即将上线")
                            .disabled(true)
                        SettingsDivider()
                        SettingsRow(title: "导入游客数据", systemImage: "square.and.arrow.down", value: "即将上线")
                            .disabled(true)
                        if accounts.account != nil {
                            SettingsDivider()
                            Button { confirmsLogout = true } label: {
                                SettingsRow(title: "退出登录", systemImage: "rectangle.portrait.and.arrow.right",
                                            showsChevron: false)
                            }
                            .buttonStyle(.plain)
                        }
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
            .sheet(isPresented: $showsAuthSheet) {
                AuthSheet()
            }
            .confirmationDialog("确定退出登录吗？", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) {
                    Task { await accounts.logout() }
                }
            }
        }
    }

    private var accountCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.fieldFill))

            VStack(alignment: .leading, spacing: 4) {
                Text(accounts.account?.email ?? "游客")
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(accounts.account == nil ? "数据仅保存在本机" : "已登录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if accounts.account == nil {
                Button("登录 / 注册") { showsAuthSheet = true }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.onInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.ink))
                    .buttonStyle(.plain)
            }
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
        .environment(AccountManager())
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
