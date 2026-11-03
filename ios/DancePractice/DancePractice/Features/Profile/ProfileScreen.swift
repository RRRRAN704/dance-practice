//
//  ProfileScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The Profile tab: account, sync, guest import and settings.
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

                    SettingsGroup(title: "Account & Sync") {
                        syncRow
                        SettingsDivider()
                        importRow
                        if accounts.account != nil {
                            SettingsDivider()
                            Button { confirmsLogout = true } label: {
                                SettingsRow(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right",
                                            showsChevron: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsGroup(title: "Settings") {
                        appearanceMenu
                        SettingsDivider()
                        NavigationLink {
                            StorageScreen()
                        } label: {
                            SettingsRow(
                                title: "Storage",
                                systemImage: "internaldrive",
                                value: usedBytes.map(StorageUsage.format)
                            )
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        SettingsRow(title: "Feedback", systemImage: "envelope", value: String(localized: "Coming soon"))
                            .disabled(true)
                        SettingsDivider()
                        NavigationLink {
                            AboutScreen()
                        } label: {
                            SettingsRow(title: "About", systemImage: "info.circle")
                        }
                        .buttonStyle(.plain)
                    }

                    if accounts.account != nil {
                        SettingsGroup {
                            Button { confirmsDelete = true } label: {
                                SettingsRow(title: "Delete Account", systemImage: "person.crop.circle.badge.xmark",
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
            .navigationTitle("Profile")
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
            .confirmationDialog("Sign out?", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await accounts.logout() }
                }
            } message: {
                Text("You'll switch back to guest data. This account's data stays on this device for next time you sign in.")
            }
            .confirmationDialog("Import guest data?", isPresented: $confirmsImport, titleVisibility: .visible) {
                Button("Import") { importGuestData() }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("This device has \(guestData.rooms) guest rooms and \(guestData.sessions) practice sessions. Import them into this account to sync them to the cloud. Guest data is kept, and importing again only updates — it never duplicates.")
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete Account Permanently", role: .destructive) { deleteAccount() }
            } message: {
                Text("Your rooms and practice history will be permanently deleted from the cloud, along with this account's data and videos on this device. This can't be undone. Guest data isn't affected.")
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK") {}
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
                Text(accounts.account?.email ?? String(localized: "Guest"))
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(accounts.account == nil ? "Data is saved only on this device" : "Signed in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if accounts.account == nil {
                Button("Sign In / Sign Up") { showsAuthSheet = true }
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
            SettingsRow(title: "Cloud Sync", systemImage: "icloud", value: String(localized: "Sign in to use"))
                .disabled(true)
        } else {
            // Tapping syncs now; a tap mid-sync just makes the running one go around again.
            Button {
                Task { await sync.syncNow() }
            } label: {
                SettingsRow(title: "Cloud Sync", systemImage: sync.status == .failed ? "exclamationmark.icloud" : "icloud",
                            value: syncStatusText, showsChevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var importRow: some View {
        if accounts.account == nil {
            SettingsRow(title: "Import Guest Data", systemImage: "square.and.arrow.down", value: String(localized: "Sign in to use"))
                .disabled(true)
        } else {
            Button { confirmsImport = true } label: {
                SettingsRow(title: "Import Guest Data", systemImage: "square.and.arrow.down",
                            value: guestData.isEmpty ? String(localized: "No guest data") : String(localized: "\(guestData.rooms) rooms"),
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

    /// Offers the import once per device, after the first login that finds guest data. Guest data
    /// is usually the phone owner's, so a friend signing in later shouldn't be nudged to take it;
    /// the row above still imports by hand.
    private func offerImportOnce() {
        guard accounts.account != nil, !guestData.isEmpty,
              !UserDefaults.standard.bool(forKey: Self.importOfferedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.importOfferedKey)
        confirmsImport = true
    }

    private func importGuestData() {
        guard let accountID = accounts.account?.id else { return }
        do {
            let imported = try GuestImporter.importGuestData(into: modelContext, accountID: accountID)
            notice = imported.isEmpty
                ? String(localized: "Guest data was already imported and is now up to date")
                : String(localized: "Imported \(imported.rooms) rooms and \(imported.sessions) practice sessions")
            sync.requestSync()
        } catch {
            notice = String(localized: "Import failed: \(error.localizedDescription)")
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
            } catch {
                notice = String(localized: "Delete failed: \(error.localizedDescription)")
            }
        }
    }

    private static let importOfferedKey = "guestImport.offered"

    private var syncStatusText: String {
        switch sync.status {
        case .syncing: String(localized: "Syncing…")
        case .failed: String(localized: "Sync failed. Tap to retry.")
        case .idle: sync.lastSyncedAt.map { String(localized: "Last synced \(TimeFormat.lastPracticed($0))") } ?? String(localized: "Tap to sync")
        }
    }

    private var appearanceMenu: some View {
        Menu {
            Picker("Dark Mode", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        } label: {
            SettingsRow(title: "Dark Mode", systemImage: "moon", value: String(localized: appearance.displayName))
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
