//
//  TimelineBar.swift
//  DancePractice
//

import SwiftUI

/// Scrubbable progress bar with A-B markers.
/// The thumbnail strip (Step 5) will be layered behind the track later.
struct TimelineBar: View {
    let currentTime: Double
    let duration: Double
    let markA: Double?
    let markB: Double?
    let isLoopEnabled: Bool
    let onScrubBegan: () -> Void
    let onScrub: (Double) -> Void
    let onScrubEnded: () -> Void

    @State private var isDragging = false

    private let trackHeight: CGFloat = 6
    private let markerRowHeight: CGFloat = 22

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let trackY = markerRowHeight + 12

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: width, height: trackHeight)
                        .position(x: width / 2, y: trackY)

                    if let markA, let markB {
                        let startX = x(for: markA, width: width)
                        let endX = x(for: markB, width: width)
                        Rectangle()
                            .fill(Theme.accent.opacity(isLoopEnabled ? 0.6 : 0.3))
                            .frame(width: max(endX - startX, 1), height: trackHeight + 6)
                            .position(x: (startX + endX) / 2, y: trackY)
                    }

                    Capsule()
                        .fill(Color.white)
                        .frame(width: x(for: currentTime, width: width), height: trackHeight)
                        .position(x: x(for: currentTime, width: width) / 2, y: trackY)

                    if let markA {
                        ABMarker(letter: "A")
                            .position(x: x(for: markA, width: width), y: markerRowHeight / 2)
                    }
                    if let markB {
                        ABMarker(letter: "B")
                            .position(x: x(for: markB, width: width), y: markerRowHeight / 2)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 20 : 14, height: isDragging ? 20 : 14)
                        .shadow(radius: 2)
                        .position(x: x(for: currentTime, width: width), y: trackY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                onScrubBegan()
                            }
                            onScrub(time(for: value.location.x, width: width))
                        }
                        .onEnded { _ in
                            isDragging = false
                            onScrubEnded()
                        }
                )
            }
            .frame(height: markerRowHeight + 24)

            HStack {
                Text(TimeFormat.clock(currentTime))
                Spacer()
                Text(TimeFormat.clock(duration))
                    .foregroundStyle(.secondary)
            }
            .font(.caption.monospacedDigit())
        }
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

/// Small "A" / "B" flag shown above the timeline.
struct ABMarker: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent))
    }
}

#Preview {
    TimelineBar(
        currentTime: 37, duration: 198, markA: 32, markB: 41, isLoopEnabled: true,
        onScrubBegan: {}, onScrub: { _ in }, onScrubEnded: {}
    )
    .padding()
    .background(Theme.playerBackground)
    .preferredColorScheme(.dark)
}
