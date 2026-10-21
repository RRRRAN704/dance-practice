//
//  HomeScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 首页 tab: today's numbers and a quick way back into recent rooms.
struct HomeScreen: View {
    /// Switches to the 练习室 tab; the tab bar is owned by RootTabView.
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
            Text("今天也要一起变更好！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近练习室")
                    .font(.title3.weight(.bold))
                Spacer()
                if !rooms.isEmpty {
                    Button(action: onShowAllRooms) {
                        HStack(spacing: 2) {
                            Text("查看全部")
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
            Text("还没有练习室")
                .font(.headline)
            Text("创建第一个练习室，开始扒舞吧")
                .font(.footnote)
                .foregroundStyle(.secondary)
            PrimaryButton(title: "去创建", systemImage: "plus", action: onShowAllRooms)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 20)
    }

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<11: "早上好"
        case 11..<13: "中午好"
        case 13..<18: "下午好"
        default: "晚上好"
        }
    }
}

#Preview {
    HomeScreen {}
        .modelContainer(for: [PracticeRoom.self, PracticeSession.self], inMemory: true)
}
