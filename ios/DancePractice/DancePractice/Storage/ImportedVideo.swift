//
//  ImportedVideo.swift
//  DancePractice
//

import CoreTransferable
import UniformTypeIdentifiers

/// A video picked from Photos, copied into the app sandbox on import.
struct ImportedVideo: Transferable, Hashable, Identifiable {
    let url: URL

    var id: URL { url }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // The received file is temporary, so keep our own copy.
            ImportedVideo(url: try VideoFileStore.importVideo(from: received.file))
        }
    }
}
