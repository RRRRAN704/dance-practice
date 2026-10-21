//
//  StorageScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// How much space the imported videos use, per room, plus cleanup of files no room references.
struct StorageScreen: View {
    @Query private var rooms: [PracticeRoom]
    @State private var sizes: [String: Int64] = [:]
    @State private var isConfirmingCleanup = false

    var body: some View {
        // The room form is a modal over the rooms tab, so a half-imported (not yet referenced)
        // video can't exist while this screen is open; its cleanup can't delete one.
        let referenced = Set(rooms.flatMap(\.fileNames))
        let orphans = StorageUsage.orphans(sizes: sizes, referenced: referenced)
        let orphanBytes = StorageUsage.bytes(of: orphans, sizes: sizes)
        let total = sizes.values.reduce(0, +)
        let roomsBySize = rooms
            .map { (room: $0, bytes: StorageUsage.bytes(of: $0.fileNames, sizes: sizes)) }
            .sorted { $0.bytes > $1.bytes }

        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已使用")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(StorageUsage.format(total))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("\(rooms.count) 个练习室的视频和封面")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)

                if orphanBytes > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("有 \(StorageUsage.format(orphanBytes)) 的文件不属于任何练习室，可以安全清理。")
                            .font(.subheadline)
                        PrimaryButton(title: "清理未使用的文件", systemImage: "trash") {
                            isConfirmingCleanup = true
                        }
                    }
                    .cardStyle(padding: 16)
                }

                if !roomsBySize.isEmpty {
                    SettingsGroup(title: "各练习室占用") {
                        ForEach(Array(roomsBySize.enumerated()), id: \.element.room.id) { index, item in
                            if index > 0 { SettingsDivider() }
                            roomRow(item.room, bytes: item.bytes)
                        }
                    }
                }

                Text("要释放更多空间，可以在练习室页面删除不再需要的练习室。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sizes = VideoFileStore.fileSizes() }
        .confirmationDialog("清理未使用的文件？", isPresented: $isConfirmingCleanup, titleVisibility: .visible) {
            Button("清理 \(StorageUsage.format(orphanBytes))", role: .destructive) {
                orphans.forEach(VideoFileStore.delete(fileName:))
                sizes = VideoFileStore.fileSizes()
            }
        } message: {
            Text("只会删除不属于任何练习室的文件，练习室不受影响。")
        }
    }

    private func roomRow(_ room: PracticeRoom, bytes: Int64) -> some View {
        HStack(spacing: 12) {
            CoverImage(url: room.coverURL)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(room.name)
                .lineLimit(1)
            Spacer()
            Text(StorageUsage.format(bytes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
