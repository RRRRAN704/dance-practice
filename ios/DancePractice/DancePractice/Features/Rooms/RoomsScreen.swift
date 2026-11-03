//
//  RoomsScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// The Rooms tab: every room, newest first. Tapping one opens the player.
struct RoomsScreen: View {
    @Query(sort: \PracticeRoom.createdAt, order: .reverse) private var rooms: [PracticeRoom]
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var sync: SyncService?

    @State private var isCreating = false
    @State private var editingRoom: PracticeRoom?
    @State private var roomToDelete: PracticeRoom?
    /// nil = All.
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
            .navigationTitle("My Rooms")
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
                    .accessibilityLabel("Create Room")
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
                "Delete “\(roomToDelete?.name ?? "")”?",
                isPresented: isConfirmingDelete,
                titleVisibility: .visible,
                presenting: roomToDelete
            ) { room in
                Button("Delete", role: .destructive) { delete(room) }
            } message: { _ in
                Text("The room and its imported video will be deleted. This can't be undone.")
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
                "No \(genreFilter.map { String(localized: $0.displayName) } ?? "") rooms",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Try another genre, or create a new room.")
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
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                roomToDelete = room
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More Actions")
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
                Text("No practice rooms yet")
                    .font(.title3.weight(.bold))
                Text("Import a dance video to start learning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            PrimaryButton(title: "Create Room", systemImage: "plus") { isCreating = true }
                .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    RoomsScreen()
        .modelContainer(for: [PracticeRoom.self, DeletedRoom.self], inMemory: true)
}
