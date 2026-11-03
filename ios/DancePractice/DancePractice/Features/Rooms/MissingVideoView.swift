//
//  MissingVideoView.swift
//  DancePractice
//

import PhotosUI
import SwiftUI

/// Shown instead of the player when a room's video isn't on this phone, e.g. a room synced from
/// another device (videos are never uploaded). Picking the video again links it to the room.
struct MissingVideoView: View {
    let room: PracticeRoom
    let onRelinked: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selection: PhotosPickerItem?
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accent)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Theme.surface))

            VStack(spacing: 8) {
                Text("Video Not on This Device")
                    .font(.title3.weight(.bold))
                Text("Rooms and practice history sync, but a video stays on the device that imported it. Choose the same video from your photo library to practise on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selection, matching: .videos) {
                PrimaryButtonLabel(title: isImporting ? "Importing…" : "Choose Video Again", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
            .padding(.top, 6)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selection) { _, item in
            Task { await relink(item) }
        }
    }

    private func relink(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isImporting = true
        errorMessage = nil
        defer {
            isImporting = false
            selection = nil
        }
        do {
            guard let imported = try await item.loadTransferable(type: ImportedVideo.self) else {
                errorMessage = String(localized: "Couldn't read this video")
                return
            }
            let oldCover = room.coverFileName
            room.videoFileName = imported.url.lastPathComponent
            room.coverFileName = await VideoFileStore.makeCover(for: imported.url)
            oldCover.map(VideoFileStore.delete(fileName:))
            // File names are this device's own, so this isn't an edit to sync (no markEdited).
            try? modelContext.save()
            onRelinked()
        } catch {
            errorMessage = String(localized: "Import failed: \(error.localizedDescription)")
        }
    }
}
