//
//  ContentView.swift
//  DancePractice
//
//  Created by Yiran on 02/10/2026.
//

import PhotosUI
import SwiftUI

/// Temporary debug entry: pick a video and open the player.
/// Will be replaced by the tab bar + practice rooms in Step 6.
struct ContentView: View {
    @State private var selection: PhotosPickerItem?
    @State private var video: ImportedVideo?
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "figure.dance")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("选择一个舞蹈视频开始练习")
                    .font(.headline)

                PhotosPicker(selection: $selection, matching: .videos) {
                    Label("从相册导入视频", systemImage: "video.badge.plus")
                }
                .buttonStyle(.borderedProminent)
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
            .padding()
            .navigationDestination(item: $video) { video in
                PlayerScreen(videoURL: video.url, title: "练习视频")
            }
            .onChange(of: selection) { _, item in
                Task { await importVideo(item) }
            }
        }
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
                video = imported
            } else {
                errorMessage = "无法读取该视频"
            }
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
