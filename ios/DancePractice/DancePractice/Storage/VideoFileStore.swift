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

    private static var directoryURL: URL {
        URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
    }
}
