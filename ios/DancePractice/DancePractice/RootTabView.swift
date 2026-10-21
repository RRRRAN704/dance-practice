//
//  RootTabView.swift
//  DancePractice
//

import SwiftUI

/// The app's four tabs. Each tab owns its own NavigationStack.
struct RootTabView: View {
    enum Tab {
        case home, rooms, stats, profile
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeScreen { selection = .rooms }
                .tabItem { Label("首页", systemImage: "house") }
                .tag(Tab.home)

            RoomsScreen()
                .tabItem { Label("练习室", systemImage: "rectangle.stack") }
                .tag(Tab.rooms)

            TabPlaceholder(title: "统计", systemImage: "chart.bar")
                .tabItem { Label("统计", systemImage: "chart.bar") }
                .tag(Tab.stats)

            TabPlaceholder(title: "我的", systemImage: "person")
                .tabItem { Label("我的", systemImage: "person") }
                .tag(Tab.profile)
        }
    }
}

/// Stand-in for a tab that hasn't been built yet.
private struct TabPlaceholder: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("即将上线"))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
