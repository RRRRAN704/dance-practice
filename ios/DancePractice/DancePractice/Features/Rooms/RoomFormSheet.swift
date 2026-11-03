//
//  RoomFormSheet.swift
//  DancePractice
//

import PhotosUI
import SwiftData
import SwiftUI

/// Creates a practice room, or edits one when `room` is given.
struct RoomFormSheet: View {
    /// nil means creating a new room.
    let room: PracticeRoom?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var sync: SyncService?

    @State private var name: String
    @State private var artist: String
    @State private var genre: DanceGenre?
    @State private var note: String

    @State private var selection: PhotosPickerItem?
    /// A video copied into the sandbox but not saved to a room yet.
    @State private var pendingVideoFileName: String?
    /// Cover made from the pending video; follows its lifecycle.
    @State private var pendingCoverFileName: String?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var didSave = false

    init(room: PracticeRoom? = nil) {
        self.room = room
        _name = State(initialValue: room?.name ?? "")
        _artist = State(initialValue: room?.artist ?? "")
        _genre = State(initialValue: room?.genre)
        _note = State(initialValue: room?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        videoCard
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    LabeledField(title: "Room Name", isRequired: true) {
                        TextField("e.g. Smoothie", text: $name)
                            .textFieldStyle(.app)
                    }

                    LabeledField(title: "Artist / Group") {
                        TextField("e.g. NCT DREAM", text: $artist)
                            .textFieldStyle(.app)
                    }

                    LabeledField(title: "Genre") {
                        genreGrid
                    }

                    LabeledField(title: "Notes") {
                        TextField("e.g. Focus on the chorus", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.app)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isEditing ? "Save Changes" : "Create Room") { save() }
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Color(.systemBackground))
            }
            .navigationTitle(isEditing ? "Edit Room" : "New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.fieldFill))
                    }
                    .disabled(isImporting)
                    .accessibilityLabel("Cancel")
                }
            }
            // A swipe-down mid-import would leave the copied file behind.
            .interactiveDismissDisabled(isImporting)
            .onChange(of: selection) { _, item in
                Task { await importVideo(item) }
            }
            .onDisappear {
                // Cancelled or swiped away: drop the video nobody will reference.
                if !didSave {
                    discardPendingFiles()
                }
            }
        }
    }

    // MARK: - Video card

    private var videoCard: some View {
        PhotosPicker(selection: $selection, matching: .videos) {
            // Clear 16:9 base sets the size; the cover fills it and gets clipped.
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if hasVideo {
                        CoverImage(url: displayedCoverURL)
                            .overlay(alignment: .bottomTrailing) { changeVideoPill }
                    } else {
                        emptyVideoPrompt
                    }
                }
                .overlay {
                    if isImporting {
                        ZStack {
                            Color.black.opacity(0.4)
                            ProgressView("Importing…")
                                .tint(.white)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .accessibilityLabel(hasVideo ? "Change Video" : "Choose Video")
    }

    private var emptyVideoPrompt: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(Theme.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.accent)
                    Text("Tap to choose a video")
                        .font(.headline)
                    Text("Import a dance video from your photo library")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var changeVideoPill: some View {
        Label("Change Video", systemImage: "arrow.triangle.2.circlepath")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
    }

    // MARK: - Genre

    private var genreGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(DanceGenre.allCases) { option in
                SelectableChip(title: option.displayName, isSelected: genre == option, fillsWidth: true) {
                    // Tapping the selected genre again clears it; genre is optional.
                    genre = genre == option ? nil : option
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditing: Bool { room != nil }

    private var canSave: Bool {
        // An edited room already has a video; a new one needs one picked.
        !trimmedName.isEmpty && (isEditing || pendingVideoFileName != nil) && !isImporting
    }

    /// An edited room already has a video, even before a new one is picked.
    private var hasVideo: Bool {
        pendingVideoFileName != nil || isEditing
    }

    /// The new pick's cover wins over the room's existing one.
    private var displayedCoverURL: URL? {
        if pendingVideoFileName != nil {
            return pendingCoverFileName.map(VideoFileStore.url(for:))
        }
        return room?.coverURL
    }

    private func save() {
        if let room {
            room.name = trimmedName
            room.artist = Self.nilIfBlank(artist)
            room.genre = genre
            room.note = Self.nilIfBlank(note)
            if let pendingVideoFileName {
                let oldFileNames = room.fileNames
                room.videoFileName = pendingVideoFileName
                room.coverFileName = pendingCoverFileName
                oldFileNames.forEach(VideoFileStore.delete(fileName:))
            }
            room.markEdited()
        } else {
            guard let pendingVideoFileName else { return }
            modelContext.insert(PracticeRoom(
                name: trimmedName,
                videoFileName: pendingVideoFileName,
                coverFileName: pendingCoverFileName,
                artist: Self.nilIfBlank(artist),
                genre: genre,
                note: Self.nilIfBlank(note)
            ))
        }
        didSave = true
        sync?.requestSync()
        dismiss()
    }

    private func importVideo(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isImporting = true
        errorMessage = nil
        defer {
            isImporting = false
            selection = nil
        }
        do {
            if let imported = try await item.loadTransferable(type: ImportedVideo.self) {
                // Picking again replaces the earlier copy.
                discardPendingFiles()
                pendingVideoFileName = imported.url.lastPathComponent
                pendingCoverFileName = await VideoFileStore.makeCover(for: imported.url)
            } else {
                errorMessage = String(localized: "Couldn't read this video")
            }
        } catch {
            errorMessage = String(localized: "Import failed: \(error.localizedDescription)")
        }
    }

    private func discardPendingFiles() {
        [pendingVideoFileName, pendingCoverFileName]
            .compactMap { $0 }
            .forEach(VideoFileStore.delete(fileName:))
        pendingVideoFileName = nil
        pendingCoverFileName = nil
    }

    private static func nilIfBlank(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    RoomFormSheet()
        .modelContainer(for: PracticeRoom.self, inMemory: true)
}
