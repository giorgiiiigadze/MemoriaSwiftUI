import SwiftUI

/// Deterministic fallback-avatar styling for users without a photo: a stable background colour
/// derived from the name — so it never changes until they upload a picture — plus their first
/// initial. A faithful port of the RN `avatarColors` palette + `pickColor` hash, so a given name
/// maps to the same colour across both clients.
enum AvatarPalette {
    /// The ten fallback colours, in the RN palette's order — the hash indexes into this list.
    static let colors: [Color] = hexValues.map { Color(hex: $0) }

    private static let hexValues: [UInt32] = [
        0xE74C3C, 0xE67E22, 0x27AE60, 0x2ECC71, 0x1ABC9C,
        0x2980B9, 0x8E44AD, 0xD81B60, 0x0097A7, 0xFF5722,
    ]

    /// Initial's font size as a fraction of the avatar's diameter (RN used `size * 0.42`).
    static let initialScale: CGFloat = 0.42

    /// Stable colour for `name` — the same string always maps to the same colour. Mirrors the RN
    /// `pickColor` hash exactly: `((hash << 5) - hash)` accumulated over UTF-16 code units, where
    /// JS coerces to a 32-bit int only at the shift while the subtraction keeps full precision.
    static func color(for name: String) -> Color {
        var hash = 0
        for unit in name.utf16 {
            let shifted = Int(Int32(truncatingIfNeeded: hash) &<< 5)
            hash = Int(unit) + (shifted - hash)
        }
        return colors[abs(hash) % colors.count]
    }

    /// The one or two uppercase initials shown over the colour: the first letter of each of the
    /// first two words (so "Giorgi Giorgadze" → "GG", "Ada" → "A"), or "?" for an empty name.
    static func initials(for name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
