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

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: PracticeRoom.self)
    }
}
