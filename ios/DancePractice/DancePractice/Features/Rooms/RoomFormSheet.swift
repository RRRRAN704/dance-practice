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

    @State private var name: String
    @State private var artist: String
    @State private var genre: DanceGenre?
    @State private var note: String

    @State private var selection: PhotosPickerItem?
    /// A video copied into the sandbox but not saved to a room yet.
    @State private var pendingVideoFileName: String?
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
            Form {
                Section("视频") {
                    PhotosPicker(selection: $selection, matching: .videos) {
                        Label(videoPickerTitle, systemImage: videoPickerIcon)
                    }
                    .disabled(isImporting)

                    if isImporting {
                        ProgressView("正在导入…")
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("信息") {
                    TextField("练习室名称（必填）", text: $name)
                    TextField("歌手 / 团体", text: $artist)
                    Picker("舞种", selection: $genre) {
                        Text("未选择").tag(DanceGenre?.none)
                        ForEach(DanceGenre.allCases) { genre in
                            Text(genre.displayName).tag(DanceGenre?.some(genre))
                        }
                    }
                }

                Section("备注") {
                    TextField("例如：副歌部分重点练", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "编辑练习室" : "创建练习室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "创建") { save() }
                        .disabled(!canSave)
                }
            }
            // A swipe-down mid-import would leave the copied file behind.
            .interactiveDismissDisabled(isImporting)
            .onChange(of: selection) { _, item in
                Task { await importVideo(item) }
            }
            .onDisappear {
                // Cancelled or swiped away: drop the video nobody will reference.
                if !didSave, let pendingVideoFileName {
                    VideoFileStore.delete(fileName: pendingVideoFileName)
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

    private var videoPickerTitle: String {
        if pendingVideoFileName != nil { return "已选择，点击更换" }
        return isEditing ? "更换视频" : "从相册选择视频"
    }

    private var videoPickerIcon: String {
        pendingVideoFileName != nil ? "checkmark.circle.fill" : "video.badge.plus"
    }

    private func save() {
        if let room {
            room.name = trimmedName
            room.artist = Self.nilIfBlank(artist)
            room.genre = genre
            room.note = Self.nilIfBlank(note)
            if let pendingVideoFileName {
                let oldFileName = room.videoFileName
                room.videoFileName = pendingVideoFileName
                VideoFileStore.delete(fileName: oldFileName)
            }
        } else {
            guard let pendingVideoFileName else { return }
            modelContext.insert(PracticeRoom(
                name: trimmedName,
                videoFileName: pendingVideoFileName,
                artist: Self.nilIfBlank(artist),
                genre: genre,
                note: Self.nilIfBlank(note)
            ))
        }
        didSave = true
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
                if let pendingVideoFileName {
                    VideoFileStore.delete(fileName: pendingVideoFileName)
                }
                pendingVideoFileName = imported.url.lastPathComponent
            } else {
                errorMessage = "无法读取该视频"
            }
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
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
