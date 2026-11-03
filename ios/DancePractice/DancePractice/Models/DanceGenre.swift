//
//  DanceGenre.swift
//  DancePractice
//

import Foundation

/// Dance style of a practice room. The raw value is what gets persisted, so don't rename cases.
enum DanceGenre: String, CaseIterable, Identifiable {
    case kpop
    case jazz
    case hiphop
    case urban
    case other

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .kpop: "Kpop"
        case .jazz: "Jazz"
        case .hiphop: "HipHop"
        case .urban: "Urban"
        case .other: "Other"
        }
    }
}
