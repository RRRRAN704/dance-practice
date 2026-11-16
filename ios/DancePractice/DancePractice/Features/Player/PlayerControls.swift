//
//  PlayerControls.swift
//  DancePractice
//

import SwiftUI

// Player controls wired to `PlayerViewModel`, shared by the regular and fullscreen layouts.

struct PlayerTimeline: View {
    let viewModel: PlayerViewModel
    var style: TimelineBar.Style = .card

    var body: some View {
        TimelineBar(
            currentTime: viewModel.currentTime,
            duration: viewModel.duration,
            markA: viewModel.markA,
            markB: viewModel.markB,
            isLoopEnabled: viewModel.isLoopEnabled,
            thumbnails: viewModel.thumbnails,
            style: style,
            onScrubBegan: viewModel.beginScrubbing,
            onScrub: viewModel.scrub(to:),
            onScrubEnded: viewModel.endScrubbing,
            onHandleDragBegan: viewModel.beginHandleDrag,
            onMoveHandle: viewModel.moveHandle(_:to:),
            onHandleDragEnded: viewModel.endHandleDrag
        )
    }
}

struct PlayerSpeedSlider: View {
    let viewModel: PlayerViewModel
    var style: SpeedSlider.Style = .regular

    var body: some View {
        SpeedSlider(
            speed: Binding(get: { viewModel.speed }, set: { viewModel.setSpeed($0) }),
            range: PlayerViewModel.speedRange,
            step: PlayerViewModel.speedStep,
            style: style
        )
    }
}

struct MirrorButton: View {
    let viewModel: PlayerViewModel
    var showsTitle = true

    var body: some View {
        ControlButton(
            title: "Mirror",
            systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
            isActive: viewModel.isMirrored,
            showsTitle: showsTitle,
            action: viewModel.toggleMirror
        )
    }
}

struct LoopButton: View {
    let viewModel: PlayerViewModel
    var showsTitle = true

    var body: some View {
        ControlButton(
            title: "A-B Loop",
            systemImage: "repeat",
            isActive: viewModel.isLoopEnabled,
            showsTitle: showsTitle,
            action: viewModel.toggleLoop
        )
    }
}

/// Beat count menu: tap along to start counting, stop where the music stops, count/click on or off, clear.
struct BeatCountButton: View {
    let viewModel: PlayerViewModel
    var showsTitle = true

    var body: some View {
        Menu {
            if let segment = viewModel.beatGrid.segment(at: viewModel.currentTime) {
                Section("\(Int(segment.bpm.rounded())) BPM") {
                    menuItems
                }
            } else {
                menuItems
            }
        } label: {
            ControlButtonLabel(
                title: "Count",
                systemImage: "metronome",
                isActive: !viewModel.beatGrid.isEmpty && viewModel.isBeatCountVisible,
                showsTitle: showsTitle
            )
        }
        .menuOrder(.fixed)
        .disabled(viewModel.duration == 0)
        .accessibilityLabel(Text("Count"))
    }

    @ViewBuilder private var menuItems: some View {
        Button(action: viewModel.startTapping) {
            Label(viewModel.beatGrid.isEmpty ? "Tap Along to Count" : "Tap Along from Here", systemImage: "hand.tap")
        }
        if viewModel.beatGrid.segment(at: viewModel.currentTime) != nil {
            Button(action: viewModel.stopCountingHere) {
                Label("Stop Counting Here", systemImage: "stop.circle")
            }
        }
        if !viewModel.beatGrid.isEmpty {
            Toggle(isOn: Binding(get: { viewModel.isBeatCountVisible }, set: { _ in viewModel.toggleBeatCountVisible() })) {
                Label("Show Count", systemImage: "eye")
            }
            Toggle(isOn: Binding(get: { viewModel.isClickSoundOn }, set: { _ in viewModel.toggleClickSound() })) {
                Label("Click Sound", systemImage: "speaker.wave.2")
            }
            Button(role: .destructive, action: viewModel.clearBeatCounts) {
                Label("Clear All Counts", systemImage: "trash")
            }
        }
    }
}

/// Placeholder for the saved-segments list.
struct SegmentListButton: View {
    var size: CGFloat = 56

    var body: some View {
        Button {} label: {
            Image(systemName: "list.bullet")
                .font(.title3)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.4)
        .accessibilityLabel("Segment List")
    }
}

/// Round translucent icon button used over fullscreen video.
struct OverlayIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringResource
    var isActive = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? Theme.accent : .white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
