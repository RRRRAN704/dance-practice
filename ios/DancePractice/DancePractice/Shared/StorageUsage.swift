//
//  StorageUsage.swift
//  DancePractice
//

import Foundation

/// Pure bookkeeping over the files in VideoFileStore: what each room uses, and what nothing uses.
enum StorageUsage {
    /// Bytes used by the given file names; files that are missing count as 0.
    static func bytes(of fileNames: [String], sizes: [String: Int64]) -> Int64 {
        fileNames.reduce(0) { $0 + (sizes[$1] ?? 0) }
    }

    /// Files on disk that no room references, e.g. left behind by a crash mid-import.
    static func orphans(sizes: [String: Int64], referenced: Set<String>) -> [String] {
        sizes.keys.filter { !referenced.contains($0) }.sorted()
    }

    /// "2.4 GB"; always numeric, so 0 reads "0 KB" rather than "Zero KB".
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}
