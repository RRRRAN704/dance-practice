//
//  TimelineBar.swift
//  DancePractice
//

import SwiftUI

/// Timeline card: current time, a scrubbable strip with a playhead, draggable A/B handles and time ticks.
/// The thumbnail strip (Step 5) fills the strip area.
struct TimelineBar: View {
    let currentTime: Double
    let duration: Double
    let markA: Double?
    let markB: Double?
    let isLoopEnabled: Bool
    let onScrubBegan: () -> Void
    let onScrub: (Double) -> Void
    let onScrubEnded: () -> Void
    let onHandleDragBegan: () -> Void
    let onMoveHandle: (LoopHandle, Double) -> Void
    let onHandleDragEnded: () -> Void

    @State private var isScrubbing = false
    @State private var draggedHandle: LoopHandle?

    private let flagRowHeight: CGFloat = 26
    private let stripHeight: CGFloat = 56
    private let handleHitWidth: CGFloat = 44
    private let coordinateSpaceName = "timeline"

    private var loopRange: (start: Double, end: Double)? {
        guard isLoopEnabled, let markA, let markB else { return nil }
        return (markA, markB)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            strip
                .frame(height: flagRowHeight + stripHeight)
            TimelineTicks(duration: duration)
                .frame(height: 30)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // Tenths matter while placing A/B, so show them during a handle drag.
            Text(draggedHandle == nil ? TimeFormat.clock(currentTime) : TimeFormat.precise(currentTime))
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
            Spacer()
            Text("/ \(TimeFormat.clock(duration))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var strip: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let stripMidY = flagRowHeight + stripHeight / 2

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: width, height: stripHeight)
                    .position(x: width / 2, y: stripMidY)

                if let loopRange {
                    let startX = x(for: loopRange.start, width: width)
                    let endX = x(for: loopRange.end, width: width)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.accent, lineWidth: 2))
                        .frame(width: max(endX - startX, 2), height: stripHeight)
                        .position(x: (startX + endX) / 2, y: stripMidY)
                }

                playhead
                    .position(x: x(for: currentTime, width: width), y: (flagRowHeight + stripHeight) / 2)

                if let loopRange {
                    handle(.a, at: loopRange.start, width: width)
                    handle(.b, at: loopRange.end, width: width)
                }
            }
            .contentShape(Rectangle())
            .coordinateSpace(name: coordinateSpaceName)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            isScrubbing = true
                            onScrubBegan()
                        }
                        onScrub(time(for: value.location.x, width: width))
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        onScrubEnded()
                    }
            )
        }
    }

    private var playhead: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.white)
                .frame(width: isScrubbing ? 20 : 16, height: isScrubbing ? 20 : 16)
                .shadow(radius: 2)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
        }
        .padding(.top, 4)
        .frame(height: flagRowHeight + stripHeight)
        .allowsHitTesting(false)
    }

    /// Flag plus a stem down the strip. The hit area is wider than it looks so it's easy to grab.
    private func handle(_ which: LoopHandle, at time: Double, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ABMarker(letter: which == .a ? "A" : "B")
                .scaleEffect(draggedHandle == which ? 1.15 : 1)
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 2)
        }
        .frame(width: handleHitWidth, height: flagRowHeight + stripHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                .onChanged { value in
                    if draggedHandle == nil {
                        draggedHandle = which
                        onHandleDragBegan()
                    }
                    onMoveHandle(which, self.time(for: value.location.x, width: width))
                }
                .onEnded { _ in
                    draggedHandle = nil
                    onHandleDragEnded()
                }
        )
        .accessibilityLabel(which == .a ? "A 点" : "B 点")
        .position(x: x(for: time, width: width), y: (flagRowHeight + stripHeight) / 2)
    }

    private func x(for time: Double, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return width * CGFloat(min(max(time / duration, 0), 1))
    }

    private func time(for x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return duration * Double(min(max(x / width, 0), 1))
    }
}

/// Tick marks under the strip, with labels at an interval that fits the video length.
private struct TimelineTicks: View {
    let duration: Double

    private let minorPerMajor = 5
    private let labelHalfWidth: CGFloat = 18

    private var majorInterval: Double {
        switch duration {
        case ..<120: 15
        case ..<300: 30
        default: 60
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            if duration > 0 {
                let minor = majorInterval / Double(minorPerMajor)
                let tickCount = Int(duration / minor)

                ZStack(alignment: .topLeading) {
                    ForEach(0...tickCount, id: \.self) { index in
                        let isMajor = index % minorPerMajor == 0
                        Rectangle()
                            .fill(Color.white.opacity(isMajor ? 0.6 : 0.25))
                            .frame(width: 1, height: isMajor ? 10 : 5)
                            .position(x: x(for: Double(index) * minor, width: width), y: 5)
                    }

                    ForEach(labelTimes(width: width), id: \.self) { time in
                        Text(TimeFormat.clock(time))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(time == duration ? .primary : .secondary)
                            .fixedSize()
                            .position(
                                x: min(max(x(for: time, width: width), labelHalfWidth), width - labelHalfWidth),
                                y: 22
                            )
                    }
                }
            }
        }
    }

    /// Major tick times plus the end, dropping the last major label if it would collide with the end label.
    private func labelTimes(width: CGFloat) -> [Double] {
        var times = stride(from: 0, to: duration, by: majorInterval).map { $0 }
        if let last = times.last, x(for: duration, width: width) - x(for: last, width: width) < labelHalfWidth * 2.2 {
            times.removeLast()
        }
        times.append(duration)
        return times
    }

    private func x(for time: Double, width: CGFloat) -> CGFloat {
        width * CGFloat(min(max(time / duration, 0), 1))
    }
}

/// Small "A" / "B" flag shown above the timeline.
struct ABMarker: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent))
    }
}

#Preview {
    TimelineBar(
        currentTime: 37, duration: 198, markA: 32, markB: 52, isLoopEnabled: true,
        onScrubBegan: {}, onScrub: { _ in }, onScrubEnded: {},
        onHandleDragBegan: {}, onMoveHandle: { _, _ in }, onHandleDragEnded: {}
    )
    .padding()
    .background(Theme.playerBackground)
    .preferredColorScheme(.dark)
}
