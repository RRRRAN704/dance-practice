//
//  DancePracticeApp.swift
//  DancePractice
//
//  Created by Yiran on 02/10/2026.
//

import SwiftData
import SwiftUI

@main
struct DancePracticeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var accounts: AccountManager
    @State private var stores: AccountStores
    @State private var sync: SyncService

    init() {
        let accounts = AccountManager()
        let stores = AccountStores()
        _accounts = State(initialValue: accounts)
        _stores = State(initialValue: stores)
        _sync = State(initialValue: SyncService(accounts: accounts, stores: stores))
    }

    var body: some Scene {
        WindowGroup {
            AccountScopedRoot(stores: stores)
                .environment(accounts)
                .environment(sync)
                .task { await accounts.verifyAccount() }
        }
    }
}

/// Gives the tabs the signed-in account's store (or the guest store); switches when the account changes.
private struct AccountScopedRoot: View {
    let stores: AccountStores
    @Environment(AccountManager.self) private var accounts
    @Environment(SyncService.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootTabView()
            .modelContainer(stores.container(for: accounts.account?.id))
            // Runs at launch and after every login, logout or account switch.
            .task(id: accounts.account?.id) {
                sync.accountDidChange()
                await sync.syncNow()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    sync.requestSync()
                }
            }
    }
}
