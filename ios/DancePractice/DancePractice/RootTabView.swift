//
//  RootTabView.swift
//  DancePractice
//

import SwiftUI

/// The app's four tabs. Each tab owns its own NavigationStack.
struct RootTabView: View {
    enum Tab: String {
        case home, rooms, stats, profile
    }

    @State private var selection: Tab = Self.initialTab
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    /// Debug builds accept `-startTab stats` (etc.) so a screen can be opened directly for screenshots.
    private static var initialTab: Tab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-startTab"), index + 1 < arguments.count,
           let tab = Tab(rawValue: arguments[index + 1]) {
            return tab
        }
        #endif
        return .home
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeScreen { selection = .rooms }
                .tabItem { Label("首页", systemImage: "house") }
                .tag(Tab.home)

            RoomsScreen()
                .tabItem { Label("练习室", systemImage: "rectangle.stack") }
                .tag(Tab.rooms)

            StatsScreen()
                .tabItem { Label("统计", systemImage: "chart.bar") }
                .tag(Tab.stats)

            ProfileScreen()
                .tabItem { Label("我的", systemImage: "person") }
                .tag(Tab.profile)
        }
        .onAppear { appearance.apply() }
        .onChange(of: appearance) { appearance.apply() }
    }
}

#Preview {
    RootTabView()
        .environment(AccountManager())
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
