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
    @Environment(SyncService.self) private var sync: SyncService?

    @State private var isCreating = false
    @State private var editingRoom: PracticeRoom?
    @State private var roomToDelete: PracticeRoom?
    /// nil = 全部.
    @State private var genreFilter: DanceGenre?

    var body: some View {
        NavigationStack {
            Group {
                if rooms.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        GenreFilterBar(selection: $genreFilter)
                            .padding(.vertical, 8)
                        roomList
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("我的练习室")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.onInk)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.ink))
                    }
                    .accessibilityLabel("创建练习室")
                }
            }
            .navigationDestination(for: PracticeRoom.self) { room in
                RoomPlayerScreen(room: room)
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

    private var filteredRooms: [PracticeRoom] {
        RoomFilter.rooms(rooms, genre: genreFilter)
    }

    @ViewBuilder
    private var roomList: some View {
        if filteredRooms.isEmpty {
            ContentUnavailableView(
                "没有\(genreFilter?.displayName ?? "")练习室",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("换个舞种看看，或者新建一个")
            )
            .frame(maxHeight: .infinity)
        } else {
            cardList
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredRooms) { room in
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
                    .cardStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
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
        let fileNames = room.fileNames
        // Recorded in guest stores too; it's a tiny row, and it keeps this screen account-agnostic.
        modelContext.insert(DeletedRoom(room: room))
        modelContext.delete(room)
        fileNames.forEach(VideoFileStore.delete(fileName:))
        sync?.requestSync()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.dance")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
                .frame(width: 96, height: 96)
                .background(Circle().fill(Theme.surface))
            VStack(spacing: 6) {
                Text("还没有练习室")
                    .font(.title3.weight(.bold))
                Text("导入一个舞蹈视频，开始扒舞")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            PrimaryButton(title: "创建练习室", systemImage: "plus") { isCreating = true }
                .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    RoomsScreen()
        .modelContainer(for: [PracticeRoom.self, DeletedRoom.self], inMemory: true)
}
