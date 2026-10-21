//
//  CoverImage.swift
//  DancePractice
//

import SwiftUI

/// A room's cover JPEG, filling its frame; a placeholder when there is none.
/// The caller sets the frame and clip shape.
struct CoverImage: View {
    let url: URL?

    var body: some View {
        // Covers are small JPEGs, so reading one synchronously is fine.
        if let url, let image = UIImage(contentsOfFile: url.path()) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "figure.dance")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
