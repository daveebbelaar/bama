import AppKit
import Observation
import SwiftUI

/// One accent color in three shades. Everything else is Apple's look.
/// People pick the accent in Settings > Appearance (AppearanceSettings.swift).
/// Light and dark mode follow the Mac: there is no app-specific mode setting.
///   APP_ACCENT=mint __APP_NAME__     run with another accent, to compare
struct Theme: Identifiable, Hashable {
    struct Shades: Hashable {
        let light: UInt32
        let base: UInt32
        let deep: UInt32
    }

    let id: String
    let name: String
    /// nil follows the accent color in System Settings.
    let shades: Shades?
    /// Text on the accent: white, or dark ink for bright accents like yellow.
    var darkText = false

    /// For `.tint`. nil keeps the system accent.
    var tint: Color? { shades.map { Color(hex: $0.base) } }
    /// The flat accent color.
    var accent: Color { tint ?? .accentColor }
    /// Accent-colored text and symbols on a plain or tinted background: the
    /// deep shade in light mode, the light shade in dark mode, so both read.
    var accentText: Color { shades.map { Color(light: $0.deep, dark: $0.light) } ?? .accentColor }
    /// Text and symbols on an accent fill.
    var onAccent: Color { darkText ? Color(hex: 0x16161C) : .white }

    static let all: [Theme] = [
        Theme(id: "system", name: "System", shades: nil),
        Theme(id: "blue", name: "Blue", shades: .init(light: 0x7CC0FF, base: 0x0A84FF, deep: 0x0064D2)),
        Theme(id: "indigo", name: "Indigo", shades: .init(light: 0xA5ADFF, base: 0x5E6AD2, deep: 0x4650B8)),
        Theme(id: "violet", name: "Violet", shades: .init(light: 0xB9A6FF, base: 0x7B5CFF, deep: 0x6342E6)),
        Theme(id: "pink", name: "Pink", shades: .init(light: 0xFF9CCB, base: 0xE84A93, deep: 0xC0306F)),
        Theme(id: "red", name: "Red", shades: .init(light: 0xFF8A9A, base: 0xE11D48, deep: 0xBE123C)),
        Theme(id: "orange", name: "Orange", shades: .init(light: 0xFFB87A, base: 0xF97316, deep: 0xC2410C)),
        Theme(id: "yellow", name: "Yellow", shades: .init(light: 0xFFE17A, base: 0xF5B800, deep: 0x946800), darkText: true),
        Theme(id: "mint", name: "Mint", shades: .init(light: 0x8EEBC4, base: 0x2BC48A, deep: 0x0F7A55), darkText: true),
        Theme(id: "teal", name: "Teal", shades: .init(light: 0x8BE9F5, base: 0x06B6D4, deep: 0x0E7490), darkText: true),
        Theme(id: "graphite", name: "Graphite", shades: .init(light: 0xC7C7CC, base: 0x7C7C84, deep: 0x55555C)),
    ]
}

/// The chosen accent, saved in UserDefaults. Views that read `theme` redraw
/// when it changes.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    /// The accent the app ships with. Keep "system", so the app follows the
    /// accent people chose for their Mac.
    static let defaultID = "system"

    /// The app's brand color, or nil. Like Apple's own apps, the brand shows
    /// only while the Mac's accent is Multicolor (System Settings >
    /// Appearance). Any other Mac accent wins. Example:
    /// Theme(id: "brand", name: "Brand", shades: .init(light: 0x8EEBC4, base: 0x2BC48A, deep: 0x0F7A55), darkText: true)
    static let brand: Theme? = nil

    var themeID: String {
        didSet { UserDefaults.standard.set(themeID, forKey: "appearance.accent") }
    }

    /// True while the Mac's accent is Multicolor.
    private(set) var macIsMulticolor = ThemeStore.readMulticolor()

    var theme: Theme {
        let chosen = Theme.all.first { $0.id == themeID } ?? Theme.all[0]
        if chosen.id == "system", macIsMulticolor, let brand = Self.brand {
            return Theme(id: "system", name: "System", shades: brand.shades, darkText: brand.darkText)
        }
        return chosen
    }

    private init() {
        themeID = ProcessInfo.processInfo.environment["APP_ACCENT"]
            ?? UserDefaults.standard.string(forKey: "appearance.accent") ?? Self.defaultID
        NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.macIsMulticolor = ThemeStore.readMulticolor() }
        }
    }

    /// The Mac stores no accent number while the accent is Multicolor.
    private static func readMulticolor() -> Bool {
        UserDefaults.standard.object(forKey: "AppleAccentColor") == nil
    }
}

/// Accent tokens for views. Never hard-code an accent hex in a view.
enum Palette {
    static var accent: Color { ThemeStore.shared.theme.accent }
    static var accentText: Color { ThemeStore.shared.theme.accentText }
    static var onAccent: Color { ThemeStore.shared.theme.onAccent }
}

extension View {
    /// Applies the chosen accent to everything below. Put it on every scene's root.
    func themed() -> some View {
        modifier(Themed())
    }
}

private struct Themed: ViewModifier {
    private var store = ThemeStore.shared

    func body(content: Content) -> some View {
        content.tint(store.theme.tint)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A color with a light and a dark value: Color(light: 0x0064D2, dark: 0x7CC0FF).
    /// Add the two high-contrast values for Increase Contrast; they default
    /// to the normal ones.
    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                               .accessibilityHighContrastDarkAqua]) {
            case .darkAqua: NSColor(hex: dark)
            case .accessibilityHighContrastAqua: NSColor(hex: highContrastLight ?? light)
            case .accessibilityHighContrastDarkAqua: NSColor(hex: highContrastDark ?? dark)
            default: NSColor(hex: light)
            }
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
