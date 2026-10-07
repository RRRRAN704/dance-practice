//
//  TimeFormat.swift
//  DancePractice
//

import Foundation

enum TimeFormat {
    /// "03:18"
    static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// "00:32.4" — used for A-B points where tenths matter.
    static func precise(_ seconds: Double) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        let tenths = Int((safe * 10).rounded(.down))
        return String(format: "%02d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }
}
