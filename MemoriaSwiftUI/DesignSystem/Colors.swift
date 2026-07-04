import SwiftUI

enum Colors {
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x161618)
    static let surfaceRaised = Color(hex: 0x242427)
    static let surfaceInput = Color(hex: 0x191919)
    static let surfaceDeep = Color(hex: 0x121212)
    static let surfaceGrouped = Color(hex: 0x1C1C1E)
    static let surfaceGroupedElevated = Color(hex: 0x2C2C2E)
    static let surfaceCard = Color(hex: 0x2C2C2C)

    static let textPrimary = Color(hex: 0xF2EEE6)
    static let textSecondary = Color(hex: 0xB8B2A6)
    static let textTertiary = Color(hex: 0x6E6E73)
    static let textMuted = Color(hex: 0x898989)
    static let textLight = Color(hex: 0xC4C4C4)
    static let textPlaceholder = Color(hex: 0x474747)

    static let borderDefault = Color(hex: 0x3B3B3B)
    static let borderSubtle = Color(hex: 0x252525)

    static let accent = Color(hex: 0xD6A45B)
    static let blue = Color(hex: 0x0A84FF)
    static let blueNotif = Color(hex: 0x3D8EFF)
    static let primary = Color(hex: 0x0044FF)
    static let success = Color(hex: 0x4CAF7D)
    // The adaptive system red, matching what `Button(role: .destructive)` uses, so error text and
    // destructive actions read as the same red.
    static let error = Color.red
    static let warning = Color(hex: 0xF59E0B)

    static let ink = Color(hex: 0x000000)
    static let bone = Color(hex: 0xF2EEE6)
    static let white = Color(hex: 0xFFFFFF)
    static let charcoal = Color(hex: 0x1B1B1B)
    static let lightBackground = Color(hex: 0xF6F6F6)

    // STATE_META colors — see DropState+Style.swift for the color+label mapping.
    static let stateActive = primary
    static let stateReady = success
    static let stateOpen = warning
    static let stateExpired = Color(hex: 0x626262)

    static let glassPanelTint = Color.white.opacity(0.08)
    static let glassChromeFallback = Color.black.opacity(0.35)
    static let glassChromeBorder = Color.white.opacity(0.2)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
