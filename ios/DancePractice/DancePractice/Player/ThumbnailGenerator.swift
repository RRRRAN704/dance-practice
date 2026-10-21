//
//  ThumbnailGenerator.swift
//  DancePractice
//

import AVFoundation

/// Extracts evenly spaced frames for the timeline strip. Knows nothing about SwiftUI.
@MainActor
enum ThumbnailGenerator {
    /// Calls `onImage` with each frame's slot index as soon as it is decoded, so the strip fills in progressively.
    /// Frames that fail to decode are skipped; their slots stay empty. Stops early when the task is cancelled.
    static func generate(
        url: URL,
        duration: Double,
        count: Int,
        maximumSize: CGSize,
        onImage: (Int, CGImage) -> Void
    ) async {
        guard duration > 0, count > 0 else { return }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        // Portrait phone videos are stored rotated; this applies the rotation.
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        // Any frame within half a slot is fine, and much faster than exact frames.
        let slot = duration / Double(count)
        let tolerance = CMTime(seconds: slot / 2, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        // Sample the middle of each slot so each thumbnail represents its stretch of the timeline.
        let times = (0..<count).map { CMTime(seconds: (Double($0) + 0.5) * slot, preferredTimescale: 600) }

        for await result in generator.images(for: times) {
            if Task.isCancelled { break }
            guard let index = times.firstIndex(of: result.requestedTime),
                  let image = try? result.image else { continue }
            onImage(index, image)
        }
    }

    /// One frame for a room's cover, taken a little way in so it's rarely a black fade-in.
    static func cover(url: URL, maximumSize: CGSize) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        let tolerance = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        // A video shorter than this still works: the generator clamps to its end.
        return try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
    }
}
