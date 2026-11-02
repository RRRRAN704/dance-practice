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

    private let container: ModelContainer = {
        #if DEBUG
        if SampleData.isRequested {
            return SampleData.makeContainer()
        }
        #endif
        // Same as `.modelContainer(for:)`, which also crashes if the store can't be opened.
        return try! ModelContainer(for: PracticeRoom.self, PracticeSession.self)
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(accounts)
                .task { await accounts.verifyAccount() }
        }
        .modelContainer(container)
    }
}
