//
//  ClickTrack.swift
//  DancePractice
//

import AVFoundation

/// Builds the audio of the beat count: a click on every counted beat, silence everywhere else.
///
/// The file is as long as the video and is mixed into it as an extra audio track (see `PlayerEngine`),
/// so it slows down, seeks and loops together with the music without any syncing code.
enum ClickTrack {
    struct Click: Equatable, Sendable {
        let time: Double
        /// The "1": a higher click, so each new eight is easy to hear.
        let isDownbeat: Bool
    }

    static let sampleRate = 22_050.0
    private static let clickLength = 0.035

    /// Every counted beat between 0 and `duration`, matching what `BeatGrid.position(at:)` shows.
    static func clicks(for grid: BeatGrid, duration: Double) -> [Click] {
        var clicks: [Click] = []
        let segments = grid.segments
        for (index, segment) in segments.enumerated() {
            var stop = min(segment.end ?? .infinity, duration)
            if index + 1 < segments.count {
                let next = segments[index + 1]
                // The next segment takes over a little before its start (see `BeatGrid.earlyTolerance`).
                stop = min(stop, next.start - BeatGrid.earlyTolerance * next.beatInterval)
            }
            var beat = 0
            while true {
                let time = segment.start + Double(beat) * segment.beatInterval
                guard time < stop else { break }
                if time >= 0 {
                    clicks.append(Click(time: time, isDownbeat: beat % BeatGrid.countsPerEight == 0))
                }
                beat += 1
            }
        }
        return clicks
    }

    /// Writes a mono file of `duration` seconds with the clicks in it, one second at a time.
    static func write(_ clicks: [Click], duration: Double, to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let chunk = AVAudioFrameCount(sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { return }

        let high = sound(frequency: 1_760, amplitude: 0.7)
        let low = sound(frequency: 1_175, amplitude: 0.5)
        let totalFrames = Int((duration * sampleRate).rounded(.up))
        var nextClick = 0

        for chunkStart in stride(from: 0, to: totalFrames, by: Int(chunk)) {
            let frames = min(Int(chunk), totalFrames - chunkStart)
            buffer.frameLength = AVAudioFrameCount(frames)
            let samples = buffer.floatChannelData![0]
            samples.update(repeating: 0, count: frames)

            // A click can start in the previous chunk and spill into this one, so look back by one click.
            var index = nextClick
            while index > 0, Int(clicks[index - 1].time * sampleRate) + high.count > chunkStart {
                index -= 1
            }
            while index < clicks.count {
                let start = Int((clicks[index].time * sampleRate).rounded())
                if start >= chunkStart + frames { break }
                let sound = clicks[index].isDownbeat ? high : low
                for i in sound.indices {
                    let frame = start + i - chunkStart
                    if frame >= 0 && frame < frames { samples[frame] += sound[i] }
                }
                index += 1
            }
            nextClick = index
            try file.write(from: buffer)
        }
    }

    /// A short woodblock-like tick: a sine wave that dies away quickly.
    private static func sound(frequency: Double, amplitude: Float) -> [Float] {
        let count = Int(clickLength * sampleRate)
        return (0..<count).map { i in
            let t = Double(i) / sampleRate
            return amplitude * Float(sin(2 * .pi * frequency * t) * exp(-t / (clickLength / 5)))
        }
    }
}
