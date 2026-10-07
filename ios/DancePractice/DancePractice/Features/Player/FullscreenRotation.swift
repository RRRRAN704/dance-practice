//
//  FullscreenRotation.swift
//  DancePractice
//

import UIKit

/// Decides whether turning the phone should enter or exit fullscreen, YouTube-style.
/// Pure so it can be unit-tested; `PlayerScreen` feeds it device orientation changes.
enum FullscreenRotation {
    enum Action: Equatable {
        case enter, exit, none
    }

    /// `previous` is the last portrait or landscape orientation (face-up/down and unknown are skipped by the caller).
    /// Only changes count, so tapping the fullscreen button while holding the phone upright doesn't bounce back out.
    /// Portrait videos ignore rotation: they're fullscreen in portrait, so turning the phone wouldn't help.
    static func action(
        previous: UIDeviceOrientation,
        current: UIDeviceOrientation,
        isFullscreen: Bool,
        isPortraitVideo: Bool
    ) -> Action {
        guard !isPortraitVideo, current != previous else { return .none }
        if current.isLandscape && !isFullscreen {
            return .enter
        }
        if current == .portrait && previous.isLandscape && isFullscreen {
            return .exit
        }
        return .none
    }

    /// Orientations worth tracking as `previous`.
    static func isTracked(_ orientation: UIDeviceOrientation) -> Bool {
        orientation == .portrait || orientation.isLandscape
    }
}
