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
    @State private var accounts = AccountManager()
    @State private var stores = AccountStores()

    var body: some Scene {
        WindowGroup {
            AccountScopedRoot(stores: stores)
                .environment(accounts)
                .task { await accounts.verifyAccount() }
        }
    }
}

/// Gives the tabs the signed-in account's store (or the guest store); switches when the account changes.
private struct AccountScopedRoot: View {
    let stores: AccountStores
    @Environment(AccountManager.self) private var accounts

    var body: some View {
        RootTabView()
            .modelContainer(stores.container(for: accounts.account?.id))
    }
}
