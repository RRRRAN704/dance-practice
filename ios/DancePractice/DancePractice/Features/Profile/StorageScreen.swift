//
//  StorageScreen.swift
//  DancePractice
//

import SwiftData
import SwiftUI

/// How much space the imported videos use, per room, plus cleanup of files no room references.
struct StorageScreen: View {
    @Environment(AccountManager.self) private var accounts
    @Query private var rooms: [PracticeRoom]
    @State private var sizes: [String: Int64] = [:]
    /// Counts hard-linked files once, unlike summing `sizes`.
    @State private var totalBytes: Int64 = 0
    /// Files used by the guest or other accounts on this phone; nil if a store couldn't be read.
    @State private var otherStoresFiles: Set<String>?
    @State private var isConfirmingCleanup = false

    var body: some View {
        // The room form is a modal over the rooms tab, so a half-imported (not yet referenced)
        // video can't exist while this screen is open; its cleanup can't delete one.
        let referenced = Set(rooms.flatMap(\.fileNames))
        // Without the other stores' references, nothing is safe to delete.
        let orphans = otherStoresFiles.map {
            StorageUsage.orphans(sizes: sizes, referenced: referenced.union($0))
        } ?? []
        let otherBytes = StorageUsage.bytes(of: Array((otherStoresFiles ?? []).subtracting(referenced)), sizes: sizes)
        let orphanBytes = StorageUsage.bytes(of: orphans, sizes: sizes)
        let roomsBySize = rooms
            .map { (room: $0, bytes: StorageUsage.bytes(of: $0.fileNames, sizes: sizes)) }
            .sorted { $0.bytes > $1.bytes }

        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Used")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(StorageUsage.format(totalBytes))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Videos and covers for \(rooms.count) rooms")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if otherBytes > 0 {
                        Text("Another \(StorageUsage.format(otherBytes)) belongs to other accounts or the guest on this device")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 16)

                if orphanBytes > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(StorageUsage.format(orphanBytes)) of files don't belong to any room and can be safely removed.")
                            .font(.subheadline)
                        PrimaryButton(title: "Remove Unused Files", systemImage: "trash") {
                            isConfirmingCleanup = true
                        }
                    }
                    .cardStyle(padding: 16)
                }

                if !roomsBySize.isEmpty {
                    SettingsGroup(title: "By Room") {
                        ForEach(Array(roomsBySize.enumerated()), id: \.element.room.id) { index, item in
                            if index > 0 { SettingsDivider() }
                            roomRow(item.room, bytes: item.bytes)
                        }
                    }
                }

                Text("To free up more space, delete rooms you no longer need on the Rooms tab.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sizes = VideoFileStore.fileSizes()
            totalBytes = VideoFileStore.totalBytes()
            otherStoresFiles = AccountStores.fileNamesInOtherStores(than: accounts.account?.id)
        }
        .confirmationDialog("Remove unused files?", isPresented: $isConfirmingCleanup, titleVisibility: .visible) {
            Button("Remove \(StorageUsage.format(orphanBytes))", role: .destructive) {
                orphans.forEach(VideoFileStore.delete(fileName:))
                sizes = VideoFileStore.fileSizes()
                totalBytes = VideoFileStore.totalBytes()
            }
        } message: {
            Text("Only files that don't belong to any room are removed. Your rooms aren't affected.")
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
