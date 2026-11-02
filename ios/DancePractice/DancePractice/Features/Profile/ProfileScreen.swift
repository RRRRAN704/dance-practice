//
//  ProfileScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 我的 tab: account, sync, guest import and settings.
struct ProfileScreen: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(AccountManager.self) private var accounts
    @Environment(SyncService.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @State private var usedBytes: Int64?
    @State private var showsAuthSheet = false
    @State private var confirmsLogout = false
    @State private var guestData = GuestImporter.Summary()
    @State private var confirmsImport = false
    @State private var confirmsDelete = false
    /// A one-line result or error, shown as an alert.
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    accountCard

                    SettingsGroup(title: "账号与同步") {
                        syncRow
                        SettingsDivider()
                        importRow
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

                    if accounts.account != nil {
                        SettingsGroup {
                            Button { confirmsDelete = true } label: {
                                SettingsRow(title: "删除账号", systemImage: "person.crop.circle.badge.xmark",
                                            showsChevron: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .navigationTitle("我的")
            // Refreshed on every return, e.g. after cleaning up on the storage screen.
            .onAppear {
                usedBytes = VideoFileStore.totalBytes()
                refreshGuestData()
            }
            .task {
                // Let the login sheet finish closing first; a dialog presented mid-dismissal is dropped.
                try? await Task.sleep(for: .milliseconds(600))
                offerImportOnce()
            }
            .sheet(isPresented: $showsAuthSheet) {
                AuthSheet()
            }
            .confirmationDialog("确定退出登录吗？", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) {
                    Task { await accounts.logout() }
                }
            } message: {
                Text("将切换回游客数据。账号的数据会保留在本机，下次登录可继续使用。")
            }
            .confirmationDialog("导入游客数据？", isPresented: $confirmsImport, titleVisibility: .visible) {
                Button("导入") { importGuestData() }
                Button("暂不导入", role: .cancel) {}
            } message: {
                Text("本机有 \(guestData.rooms) 个游客练习室、\(guestData.sessions) 条练习记录，可以导入当前账号并同步到云端。游客数据会保留；以后再导入只会更新，不会重复。")
            }
            .confirmationDialog("确定删除账号吗？", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("永久删除账号", role: .destructive) { deleteAccount() }
            } message: {
                Text("云端的练习室和练习记录会被永久删除，这台设备上该账号的数据和视频也会一起删除，且无法恢复。游客数据不受影响。")
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("好") {}
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

    @ViewBuilder
    private var syncRow: some View {
        if accounts.account == nil {
            SettingsRow(title: "云同步", systemImage: "icloud", value: "登录后可用")
                .disabled(true)
        } else {
            // Tapping syncs now; a tap mid-sync just makes the running one go around again.
            Button {
                Task { await sync.syncNow() }
            } label: {
                SettingsRow(title: "云同步", systemImage: sync.status == .failed ? "exclamationmark.icloud" : "icloud",
                            value: syncStatusText, showsChevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var importRow: some View {
        if accounts.account == nil {
            SettingsRow(title: "导入游客数据", systemImage: "square.and.arrow.down", value: "登录后可用")
                .disabled(true)
        } else {
            Button { confirmsImport = true } label: {
                SettingsRow(title: "导入游客数据", systemImage: "square.and.arrow.down",
                            value: guestData.isEmpty ? "无游客数据" : "\(guestData.rooms) 个练习室",
                            showsChevron: false)
            }
            .buttonStyle(.plain)
            .disabled(guestData.isEmpty)
        }
    }

    private func refreshGuestData() {
        guard accounts.account != nil else { return }
        guestData = GuestImporter.guestSummary()
    }

    /// Offers the import once per account, right after its first login on this device.
    private func offerImportOnce() {
        guard let accountID = accounts.account?.id else { return }
        let key = Self.importOfferedKey(accountID)
        if !guestData.isEmpty && !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            confirmsImport = true
        }
    }

    private func importGuestData() {
        guard let accountID = accounts.account?.id else { return }
        do {
            let imported = try GuestImporter.importGuestData(into: modelContext, accountID: accountID)
            notice = imported.isEmpty
                ? "游客数据都已导入过，已更新为最新"
                : "已导入 \(imported.rooms) 个练习室、\(imported.sessions) 条练习记录"
            sync.requestSync()
        } catch {
            notice = "导入失败：\(error.localizedDescription)"
        }
    }

    private func deleteAccount() {
        guard let accountID = accounts.account?.id else { return }
        Task {
            do {
                try await accounts.deleteAccount()
                // The tabs now switch to the guest store, so the account's store can go.
                AccountStores.deleteLocalData(for: accountID)
                sync.forget(accountID: accountID)
                UserDefaults.standard.removeObject(forKey: Self.importOfferedKey(accountID))
            } catch {
                notice = "删除失败：\(error.localizedDescription)"
            }
        }
    }

    private static func importOfferedKey(_ accountID: UUID) -> String {
        "guestImport.\(accountID.uuidString).offered"
    }

    private var syncStatusText: String {
        switch sync.status {
        case .syncing: "同步中…"
        case .failed: "同步失败，点此重试"
        case .idle: sync.lastSyncedAt.map { "上次 " + TimeFormat.lastPracticed($0) } ?? "点此同步"
        }
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
    let accounts = AccountManager()
    ProfileScreen()
        .environment(accounts)
        .environment(SyncService(accounts: accounts, stores: AccountStores()))
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
