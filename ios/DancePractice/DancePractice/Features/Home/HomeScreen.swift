//
//  HomeScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The Home tab: today's numbers and a quick way back into recent rooms.
struct HomeScreen: View {
    /// Switches to the Rooms tab; the tab bar is owned by RootTabView.
    var onShowAllRooms: () -> Void

    @Query private var sessions: [PracticeSession]
    @Query private var rooms: [PracticeRoom]

    private static let recentLimit = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    PracticeSummaryCard(sessions: sessions)
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PracticeRoom.self) { room in
                RoomPlayerScreen(room: room)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Self.greeting(hour: Calendar.current.component(.hour, from: .now))) 👋")
                .font(.largeTitle.weight(.bold))
            Text("Let's get a little better today!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rooms")
                    .font(.title3.weight(.bold))
                Spacer()
                if !rooms.isEmpty {
                    Button(action: onShowAllRooms) {
                        HStack(spacing: 2) {
                            Text("See All")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if rooms.isEmpty {
                noRoomsCard
            } else {
                ForEach(recentRooms) { room in
                    NavigationLink(value: room) {
                        RecentRoomRow(room: room)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentRooms: [PracticeRoom] {
        Array(rooms.sorted { $0.lastActivityAt > $1.lastActivityAt }.prefix(Self.recentLimit))
    }

    private var noRoomsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.dance")
                .font(.system(size: 30))
                .foregroundStyle(Theme.accent)
            Text("No practice rooms yet")
                .font(.headline)
            Text("Create your first room and start learning a dance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            PrimaryButton(title: "Create a Room", systemImage: "plus", action: onShowAllRooms)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 20)
    }

    /// Explicit keys because English has no noon greeting: two slots share "Good afternoon"
    /// but Chinese still tells 中午好 and 下午好 apart.
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<11: String(localized: "greeting.morning", defaultValue: "Good morning")
        case 11..<13: String(localized: "greeting.noon", defaultValue: "Good afternoon")
        case 13..<18: String(localized: "greeting.afternoon", defaultValue: "Good afternoon")
        default: String(localized: "greeting.evening", defaultValue: "Good evening")
        }
    }
}

#Preview {
    HomeScreen {}
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
