//
//  ChartPalette.swift
//  DancePractice
//

import SwiftUI

/// Chart colours, stepped separately for light and dark mode.
/// Genre colours are fixed per genre (never by rank), from a CVD-validated categorical order.
enum ChartPalette {
    static func color(for genre: DanceGenre?) -> Color {
        switch genre {
        case .kpop: dynamic(light: 0x2A78D6, dark: 0x3987E5)    // blue
        case .jazz: dynamic(light: 0xEB6834, dark: 0xD95926)    // orange
        case .hiphop: dynamic(light: 0x1BAF7A, dark: 0x199E70)  // aqua
        case .urban: dynamic(light: 0xEDA100, dark: 0xC98500)   // yellow
        case .other: dynamic(light: 0xE87BA4, dark: 0xD55181)   // magenta
        case nil: Color(.systemGray3)                           // uncategorised stays neutral
        }
    }

    static func genreName(_ genre: DanceGenre?) -> String {
        genre.map { String(localized: $0.displayName) } ?? String(localized: "Uncategorized")
    }

    /// Single-series bars.
    static let bar = dynamic(light: 0x2A78D6, dark: 0x3987E5)

    /// One blue, light to dark (dark mode runs dim to bright). Level 0 = no practice.
    static func heat(_ level: Int) -> Color {
        switch level {
        case ...0: Theme.fieldFill
        case 1: dynamic(light: 0x9EC5F4, dark: 0x184F95)
        case 2: dynamic(light: 0x5598E7, dark: 0x256ABF)
        case 3: dynamic(light: 0x256ABF, dark: 0x3987E5)
        default: dynamic(light: 0x104281, dark: 0x86B6EF)
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
