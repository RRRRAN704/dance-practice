//
//  PlayerViewModel.swift
//  DancePractice
//

import AVFoundation
import Observation

/// Player screen state: speed, mirror, A-B loop and beat count. Delegates playback to `PlayerEngine`.
@Observable
@MainActor
final class PlayerViewModel {
    nonisolated static let speedRange: ClosedRange<Double> = 0.25...2.0
    nonisolated static let speedStep: Double = 0.05
    /// Length of the loop created when A-B is turned on with no marks yet.
    nonisolated static let defaultLoopLength: Double = 8
    static let thumbnailCount = 12
    /// Pixels; tall enough for the 56pt strip at 3x.
    static let thumbnailMaxSize = CGSize(width: 300, height: 168)

    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var speed: Double = 1.0
    private(set) var isMirrored = false
    private(set) var markA: Double?
    private(set) var markB: Double?
    private(set) var isLoopEnabled = false
    private(set) var errorMessage: String?
    /// Display size of the video, after rotation; may have negative components from the transform.
    private(set) var videoSize: CGSize = .zero
    /// One slot per thumbnail; nil until that frame is decoded.
    private(set) var thumbnails: [CGImage?] = []
    private(set) var beatGrid = BeatGrid() {
        didSet {
            guard beatGrid != oldValue else { return }
            onBeatGridChange?(beatGrid)
            rebuildClickTrack()
        }
    }
    /// Remembered across videos and launches, like the pinned controls.
    private(set) var isClickSoundOn = UserDefaults.standard.object(forKey: PlayerViewModel.clickSoundKey) as? Bool ?? true
    private(set) var isBeatCountVisible = true
    /// The tap pad is up and taps are being collected.
    private(set) var isTapping = false
    private(set) var tapTempo = TapTempo()
    /// The last attempt was too uneven to use; the pad asks for another go.
    private(set) var tapsWereUneven = false
    /// Set while the taps are correcting this segment's tempo rather than starting a new one.
    private(set) var calibratingSegmentID: UUID?

    /// Lets the host save the counts; the player itself doesn't store anything.
    @ObservationIgnored var onBeatGridChange: ((BeatGrid) -> Void)?
    @ObservationIgnored private let engine = PlayerEngine()
    @ObservationIgnored private var isScrubbing = false
    @ObservationIgnored private var resumeAfterScrubbing = false
    @ObservationIgnored private var practiceTimer = PracticeTimer()
    @ObservationIgnored private var clickTrackTask: Task<Void, Never>?
    /// The click file in use, deleted when it's replaced.
    @ObservationIgnored private var clickTrackURL: URL?
    private static let clickSoundKey = "player.clickSound"
    private static let clickFilePrefix = "beat-clicks-"

    var player: AVPlayer { engine.player }

    var loopRange: LoopRange? {
        guard let markA, let markB else { return nil }
        return LoopRange(start: markA, end: markB, duration: duration)
    }

    /// The count to show now, if this moment is counted and the count isn't hidden.
    var beatPosition: BeatPosition? {
        isBeatCountVisible ? beatGrid.position(at: currentTime) : nil
    }

    /// Portrait videos stay portrait in fullscreen; landscape ones rotate.
    var isPortraitVideo: Bool { Self.isPortrait(videoSize) }

    nonisolated static func isPortrait(_ size: CGSize) -> Bool {
        abs(size.height) > abs(size.width)
    }

    init() {
        engine.onTimeChange = { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            self.currentTime = time
        }
        engine.onPlayingChange = { [weak self] isPlaying in
            guard let self else { return }
            self.isPlaying = isPlaying
            if isPlaying {
                self.practiceTimer.start(at: .now)
            } else {
                self.practiceTimer.stop(at: .now)
            }
        }
    }

    // MARK: - Playback

    func load(url: URL) async {
        do {
            let video = try await engine.load(url: url)
            duration = video.duration
            videoSize = video.displaySize
            currentTime = 0
            markA = nil
            markB = nil
            isLoopEnabled = false
            engine.setRate(Float(speed))
            engine.setClickVolume(isClickSoundOn ? 1 : 0)
            Self.removeLeftoverClickFiles()
            clickTrackURL = nil
            rebuildClickTrack()
        } catch {
            errorMessage = String(localized: "Couldn't load the video: \(error.localizedDescription)")
            return
        }
        await loadThumbnails(url: url)
    }

    /// Runs inside the screen's `.task`, so leaving the screen cancels it.
    private func loadThumbnails(url: URL) async {
        thumbnails = Array(repeating: nil, count: Self.thumbnailCount)
        await ThumbnailGenerator.generate(
            url: url,
            duration: duration,
            count: Self.thumbnailCount,
            maximumSize: Self.thumbnailMaxSize
        ) { index, image in
            thumbnails[index] = image
        }
    }

    func togglePlayPause() {
        isPlaying ? engine.pause() : engine.play()
    }

    func pause() {
        engine.pause()
    }

    /// Hands over the practice time so far and starts counting afresh; nil if too short to keep.
    func finishPractice() -> PracticeRecord? {
        practiceTimer.finish(at: .now)
    }

    /// While looping, seeks are kept inside A-B so the loop can't be left by accident.
    func seek(to time: Double) {
        currentTime = Self.clampedSeekTime(time, loop: isLoopEnabled ? loopRange : nil, duration: duration)
        engine.seek(to: currentTime)
    }

    nonisolated static func clampedSeekTime(_ time: Double, loop: LoopRange?, duration: Double) -> Double {
        if let loop {
            return min(max(time, loop.start), loop.end)
        }
        return min(max(time, 0), duration)
    }

    /// Pauses while dragging so seeks aren't fighting playback; `endScrubbing` resumes.
    func beginScrubbing() {
        isScrubbing = true
        resumeAfterScrubbing = isPlaying
        if isPlaying {
            engine.pause()
        }
    }

    func scrub(to time: Double) {
        seek(to: time)
    }

    func endScrubbing() {
        isScrubbing = false
        if resumeAfterScrubbing {
            engine.play()
        }
        resumeAfterScrubbing = false
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Speed & mirror

    func setSpeed(_ value: Double) {
        speed = Self.normalizedSpeed(value)
        engine.setRate(Float(speed))
    }

    /// Clamps to `speedRange` and snaps to `speedStep`.
    nonisolated static func normalizedSpeed(_ value: Double) -> Double {
        let clamped = min(max(value, speedRange.lowerBound), speedRange.upperBound)
        let snapped = (clamped / speedStep).rounded() * speedStep
        return (snapped * 100).rounded() / 100
    }

    func toggleMirror() {
        isMirrored.toggle()
    }

    // MARK: - A-B loop

    /// Turning on reuses the remembered marks, or creates a default segment from the current time.
    /// Turning off keeps the marks for next time.
    func toggleLoop() {
        if !isLoopEnabled, loopRange == nil {
            guard let range = Self.defaultLoopRange(at: currentTime, duration: duration) else { return }
            markA = range.start
            markB = range.end
        }
        isLoopEnabled.toggle()
        syncLoop()
    }

    /// `defaultLoopLength` starting at `time`, shifted back if it would run past the end.
    nonisolated static func defaultLoopRange(at time: Double, duration: Double) -> LoopRange? {
        let start = max(0, min(time, duration - defaultLoopLength))
        return LoopRange(start: start, end: start + defaultLoopLength, duration: duration)
    }

    /// Pauses while an A/B handle is dragged; `endHandleDrag` applies the loop and resumes.
    func beginHandleDrag() {
        beginScrubbing()
    }

    /// Moves one end of the loop and shows the frame under the handle.
    func moveHandle(_ handle: LoopHandle, to time: Double) {
        guard let range = loopRange else { return }
        let moved = handle == .a
            ? range.withStart(time, duration: duration)
            : range.withEnd(time, duration: duration)
        markA = moved.start
        markB = moved.end
        currentTime = handle == .a ? moved.start : moved.end
        engine.seek(to: currentTime)
    }

    func endHandleDrag() {
        syncLoop()
        if let markA {
            seek(to: markA)
        }
        endScrubbing()
    }

    // MARK: - Beat count

    /// Counts saved earlier for this video. Doesn't report back through `onBeatGridChange`.
    func restoreBeatGrid(_ grid: BeatGrid) {
        let callback = onBeatGridChange
        onBeatGridChange = nil
        beatGrid = grid
        onBeatGridChange = callback
    }

    /// Shows the tap pad. Starts playback, since taps follow the music.
    func startTapping() {
        beginTapping(calibrating: nil)
    }

    /// Shows the tap pad to correct the tempo of the segment counting now.
    func startCalibrating() {
        guard let segment = beatGrid.segment(at: currentTime) else { return }
        beginTapping(calibrating: segment.id)
    }

    private func beginTapping(calibrating segmentID: UUID?) {
        tapTempo.reset()
        tapsWereUneven = false
        calibratingSegmentID = segmentID
        isTapping = true
        if !isPlaying {
            engine.play()
        }
    }

    /// One tap on the beat. Reads the engine's own clock rather than `currentTime`, which only updates 30 times a second.
    func tapBeat() {
        guard isTapping else { return }
        tapsWereUneven = false
        tapTempo.tap(at: engine.currentTime)
        if tapTempo.count >= TapTempo.maximumTaps {
            finishTapping()
        }
    }

    /// Turns the taps so far into a segment, or corrects the one being calibrated.
    /// Uneven taps clear and the pad stays up for another go.
    func finishTapping() {
        let calibrating = calibratingSegmentID.flatMap { id in beatGrid.segments.first { $0.id == id } }
        let estimate = calibrating.map(tapTempo.calibrated) ?? tapTempo.estimate
        switch estimate {
        case let .segment(start, bpm):
            if var segment = calibrating {
                segment.taps = tapTempo.calibrationTaps(for: segment)
                segment.start = start
                segment.bpm = bpm
                beatGrid.replace(segment)
            } else {
                beatGrid.add(BeatSegment(start: start, bpm: bpm, taps: tapTempo.beatTaps))
            }
            isBeatCountVisible = true
            isTapping = false
            calibratingSegmentID = nil
        case .uneven:
            tapTempo.reset()
            tapsWereUneven = true
        case .needMoreTaps:
            break
        }
    }

    func cancelTapping() {
        isTapping = false
        tapTempo.reset()
        tapsWereUneven = false
        calibratingSegmentID = nil
    }

    /// The music stops here (talking, a pause): stop counting from now on.
    func stopCountingHere() {
        beatGrid.stop(at: currentTime)
    }

    func toggleBeatCountVisible() {
        isBeatCountVisible.toggle()
    }

    func clearBeatCounts() {
        beatGrid.removeAll()
    }

    func toggleClickSound() {
        isClickSoundOn.toggle()
        UserDefaults.standard.set(isClickSoundOn, forKey: Self.clickSoundKey)
        engine.setClickVolume(isClickSoundOn ? 1 : 0)
    }

    /// Writes a new click file for the current counts (off the main thread) and mixes it into playback.
    /// Rapid changes collapse into one rebuild; a rebuild in progress is abandoned for the newer one.
    private func rebuildClickTrack() {
        clickTrackTask?.cancel()
        guard duration > 0 else { return }
        let clicks = ClickTrack.clicks(for: beatGrid, duration: duration)
        let duration = duration
        clickTrackTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            var newURL: URL?
            if !clicks.isEmpty {
                let url = FileManager.default.temporaryDirectory
                    .appending(path: "\(Self.clickFilePrefix)\(UUID().uuidString).caf")
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try ClickTrack.write(clicks, duration: duration, to: url)
                    }.value
                } catch {
                    return
                }
                newURL = url
            }
            guard !Task.isCancelled else {
                newURL.map { try? FileManager.default.removeItem(at: $0) }
                return
            }
            do {
                try await engine.setClickTrack(newURL)
            } catch {
                newURL.map { try? FileManager.default.removeItem(at: $0) }
                return
            }
            if let old = clickTrackURL {
                try? FileManager.default.removeItem(at: old)
            }
            clickTrackURL = newURL
        }
    }

    /// Click files from an earlier player that closed (or crashed) before tidying up.
    private static func removeLeftoverClickFiles() {
        let directory = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasPrefix(clickFilePrefix) {
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }

    // MARK: - Private

    private func syncLoop() {
        if loopRange == nil {
            isLoopEnabled = false
        }
        engine.setLoop(isLoopEnabled ? loopRange : nil)
    }
}
