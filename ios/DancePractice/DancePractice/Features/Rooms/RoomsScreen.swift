//
//  RoomsScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 练习室 tab: every room, newest first. Tapping one opens the player.
struct RoomsScreen: View {
    @Query(sort: \PracticeRoom.createdAt, order: .reverse) private var rooms: [PracticeRoom]
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Group {
                if rooms.isEmpty {
                    emptyState
                } else {
                    List(rooms) { room in
                        NavigationLink(value: room) {
                            RoomRow(room: room)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("我的练习室")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("创建练习室")
                }
            }
            .navigationDestination(for: PracticeRoom.self) { room in
                PlayerScreen(videoURL: room.videoURL, title: room.name)
                    .toolbar(.hidden, for: .tabBar)
                    .onAppear { room.lastOpenedAt = .now }
            }
            .sheet(isPresented: $isCreating) {
                RoomFormSheet()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有练习室", systemImage: "figure.dance")
        } description: {
            Text("导入一个舞蹈视频，开始扒舞")
        } actions: {
            Button("创建练习室") { isCreating = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    RoomsScreen()
        .modelContainer(for: PracticeRoom.self, inMemory: true)
}
