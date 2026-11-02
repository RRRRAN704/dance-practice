//
//  VideoFileStore.swift
//  DancePractice
//

import UIKit

/// Owns the app's local copies of imported videos (Documents/Videos).
enum VideoFileStore {
    static func importVideo(from source: URL) throws -> URL {
        let directory = try videosDirectory()
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = directory
            .appending(path: UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func videosDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    /// Saves a room cover as JPEG next to the videos; returns its file name.
    static func saveCover(_ image: CGImage) throws -> String {
        guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = UUID().uuidString + ".jpg"
        try data.write(to: try videosDirectory().appending(path: fileName))
        return fileName
    }

    /// Makes the cover for a video in the store; nil if no frame could be decoded.
    /// A missing cover isn't worth failing an import over; rows show a placeholder.
    @MainActor
    static func makeCover(for videoURL: URL) async -> String? {
        guard let image = await ThumbnailGenerator.cover(url: videoURL, maximumSize: CGSize(width: 400, height: 400)) else {
            return nil
        }
        return try? saveCover(image)
    }

    /// A second name for a stored file, so another store's room can own it. A hard link takes no
    /// extra space, and deleting either name leaves the other working; falls back to a copy.
    /// nil if the file is missing.
    static func duplicate(fileName: String) -> String? {
        let source = url(for: fileName)
        let ext = source.pathExtension
        let newName = ext.isEmpty ? UUID().uuidString : UUID().uuidString + "." + ext
        let destination = url(for: newName)
        do {
            try FileManager.default.linkItem(at: source, to: destination)
        } catch {
            guard (try? FileManager.default.copyItem(at: source, to: destination)) != nil else { return nil }
        }
        return newName
    }

    /// Rebuilds the full path for a stored file name.
    static func url(for fileName: String) -> URL {
        directoryURL.appending(path: fileName)
    }

    /// Removes a stored file; a file that is already gone is not an error.
    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// File name → size in bytes for everything stored (videos and covers).
    static func fileSizes() -> [String: Int64] {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys
        ) else { return [:] }
        return urls.reduce(into: [:]) { sizes, url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return }
            sizes[url.lastPathComponent] = Int64(values.fileSize ?? 0)
        }
    }

    /// Space actually used: hard-linked names share their data, so each file is counted once.
    static func totalBytes() -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey, .fileResourceIdentifierKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys
        ) else { return 0 }
        var seen: [any NSObjectProtocol & NSCopying & NSSecureCoding] = []
        var total: Int64 = 0
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            if let identifier = values.fileResourceIdentifier {
                if seen.contains(where: { $0.isEqual(identifier) }) { continue }
                seen.append(identifier)
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private static var directoryURL: URL {
        URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
    }
}
