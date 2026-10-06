//
//  PlayerScreen.swift
//  DancePractice
//

import SwiftUI

struct PlayerScreen: View {
    let videoURL: URL
    let title: String

    @State private var viewModel = PlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VideoSurface(player: viewModel.player)
                .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipped()
                .onTapGesture { viewModel.togglePlayPause() }

            VStack(spacing: 14) {
                TimelineBar(
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    markA: viewModel.markA,
                    markB: viewModel.markB,
                    isLoopEnabled: viewModel.isLoopEnabled,
                    onScrubBegan: viewModel.beginScrubbing,
                    onScrub: viewModel.scrub(to:),
                    onScrubEnded: viewModel.endScrubbing
                )

                transportControls

                SpeedSlider(
                    speed: Binding(get: { viewModel.speed }, set: { viewModel.setSpeed($0) }),
                    range: PlayerViewModel.speedRange,
                    step: PlayerViewModel.speedStep
                )

                HStack(spacing: 10) {
                    ControlButton(
                        title: "镜面",
                        systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                        isActive: viewModel.isMirrored,
                        action: viewModel.toggleMirror
                    )
                    ControlButton(
                        title: "A-B 循环",
                        systemImage: "repeat",
                        isActive: viewModel.isLoopEnabled,
                        action: viewModel.toggleLoop
                    )
                    .disabled(viewModel.loopRange == nil)
                }

                LoopPointsBar(
                    markA: viewModel.markA,
                    markB: viewModel.markB,
                    onSetA: viewModel.setMarkA,
                    onSetB: { viewModel.setMarkB() },
                    onClear: viewModel.clearLoop
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Theme.playerBackground.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(url: videoURL) }
        .onDisappear { viewModel.pause() }
        .alert(
            "出错了",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("好") {}
        } message: { message in
            Text(message)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button { viewModel.skip(by: -PlayerViewModel.skipInterval) } label: {
                Image(systemName: "gobackward.5").font(.title2)
            }
            .accessibilityLabel("后退 5 秒")

            Button(action: viewModel.togglePlayPause) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.black)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(.white))
            }
            .accessibilityLabel(viewModel.isPlaying ? "暂停" : "播放")

            Button { viewModel.skip(by: PlayerViewModel.skipInterval) } label: {
                Image(systemName: "goforward.5").font(.title2)
            }
            .accessibilityLabel("前进 5 秒")
        }
        .buttonStyle(.plain)
    }
}
