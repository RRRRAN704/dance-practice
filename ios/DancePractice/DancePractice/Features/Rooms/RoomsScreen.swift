//
//  RoomsScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The 练习室 tab: every room, newest first. Tapping one opens the player.
struct RoomsScreen: View {
    @Query(sort: \PracticeRoom.createdAt, order: .reverse) private var rooms: [PracticeRoom]
    @Environment(\.modelContext) private var modelContext

    @State private var isCreating = false
    @State private var editingRoom: PracticeRoom?
    @State private var roomToDelete: PracticeRoom?

    var body: some View {
        NavigationStack {
            Group {
                if rooms.isEmpty {
                    emptyState
                } else {
                    roomList
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
            .sheet(item: $editingRoom) { room in
                RoomFormSheet(room: room)
            }
            .confirmationDialog(
                "删除「\(roomToDelete?.name ?? "")」？",
                isPresented: isConfirmingDelete,
                titleVisibility: .visible,
                presenting: roomToDelete
            ) { room in
                Button("删除", role: .destructive) { delete(room) }
            } message: { _ in
                Text("练习室和导入的视频都会被删除，无法恢复。")
            }
        }
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rooms) { room in
                    HStack(spacing: 0) {
                        // Only the left part navigates, so the menu never opens the player by accident.
                        NavigationLink(value: room) {
                            RoomRow(room: room)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        moreMenu(for: room)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func moreMenu(for room: PracticeRoom) -> some View {
        Menu {
            Button {
                editingRoom = room
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                roomToDelete = room
            } label: {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("更多操作")
    }

    /// Bridges `roomToDelete` to the Bool the dialog needs.
    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        )
    }

    private func delete(_ room: PracticeRoom) {
        let fileName = room.videoFileName
        modelContext.delete(room)
        VideoFileStore.delete(fileName: fileName)
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
