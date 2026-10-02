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
        let directory = URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
