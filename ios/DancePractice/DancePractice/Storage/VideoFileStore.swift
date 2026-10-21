//
//  VideoFileStore.swift
//  DancePractice
//

import Foundation

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

    /// Rebuilds the full path for a stored file name.
    static func url(for fileName: String) -> URL {
        directoryURL.appending(path: fileName)
    }

    /// Removes a stored file; a file that is already gone is not an error.
    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    private static var directoryURL: URL {
        URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
    }
}
