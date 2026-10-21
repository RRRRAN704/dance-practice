//
//  RoomFormSheet.swift
//  DancePractice
//

import PhotosUI
import SwiftData
import SwiftUI

/// Creates a practice room: pick a video, then fill in its details.
struct RoomFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var artist = ""
    @State private var genre: DanceGenre?
    @State private var note = ""

    @State private var selection: PhotosPickerItem?
    /// The video copied into the sandbox but not saved to a room yet.
    @State private var videoFileName: String?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("视频") {
                    PhotosPicker(selection: $selection, matching: .videos) {
                        Label(
                            videoFileName == nil ? "从相册选择视频" : "已选择，点击更换",
                            systemImage: videoFileName == nil ? "video.badge.plus" : "checkmark.circle.fill"
                        )
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
            .navigationTitle("创建练习室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { save() }
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
                if !didSave, let videoFileName {
                    VideoFileStore.delete(fileName: videoFileName)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && videoFileName != nil && !isImporting
    }

    private func save() {
        guard let videoFileName else { return }
        let room = PracticeRoom(
            name: trimmedName,
            videoFileName: videoFileName,
            artist: Self.nilIfBlank(artist),
            genre: genre,
            note: Self.nilIfBlank(note)
        )
        modelContext.insert(room)
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
                if let videoFileName {
                    VideoFileStore.delete(fileName: videoFileName)
                }
                videoFileName = imported.url.lastPathComponent
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
