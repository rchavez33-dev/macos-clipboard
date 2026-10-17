import AppKit
import SwiftUI

// MARK: - Theme
//
// 🎨 Every color used by the UI lives here. Edit a preset (or `Theme.custom`)
// and rebuild — no view code needs to change.

struct Theme {
    /// `nil` follows the system (light/dark). Use `.darkAqua` or `.aqua` to force one.
    var appearance: NSAppearance.Name?

    // Panel (the bar that slides up from the bottom of the screen)
    var panelMaterial: NSVisualEffectView.Material
    var panelTint: Color
    var panelCornerRadius: CGFloat

    // Toolbar: search field + tabs
    var searchBackground: Color
    var searchText: Color
    var tabText: Color
    var tabSelectedBackground: Color
    var tabSelectedText: Color

    // Cards
    var cardBackground: Color
    var cardBorder: Color
    var cardCornerRadius: CGFloat
    var selectionBorder: Color
    var primaryText: Color
    var secondaryText: Color
    var linkColor: Color

    // Card header
    var headerText: Color
    /// Paste tints each header with the source app's icon color. Turn off to use `headerColors`.
    var useAppIconColorForHeader: Bool
    var headerColors: [ClipKind: Color]

    func headerColor(for kind: ClipKind) -> Color {
        headerColors[kind] ?? selectionBorder
    }
}

// MARK: - Presets

extension Theme {
    /// Close to Paste's look. The orange #FF9300 is Paste's brand color,
    /// observed in its asset catalog (AppIcon_Assets/Color-2).
    static let paste = Theme(
        appearance: nil,
        panelMaterial: .hudWindow,
        panelTint: .dynamic(light: 0xF2F2F7, dark: 0x1C1C1E).opacity(0.35),
        panelCornerRadius: 18,
        searchBackground: .dynamic(light: 0xFFFFFF, dark: 0x2C2C2E).opacity(0.85),
        searchText: .dynamic(light: 0x1C1C1E, dark: 0xF2F2F7),
        tabText: .dynamic(light: 0x3A3A3C, dark: 0xD1D1D6),
        tabSelectedBackground: Color(hex: 0xFF9300),
        tabSelectedText: .white,
        cardBackground: .dynamic(light: 0xFFFFFF, dark: 0x2C2C2E),
        cardBorder: .dynamic(light: 0xE5E5EA, dark: 0x3A3A3C),
        cardCornerRadius: 14,
        selectionBorder: Color(hex: 0xFF9300),
        primaryText: .dynamic(light: 0x1C1C1E, dark: 0xF2F2F7),
        secondaryText: .dynamic(light: 0x8E8E93, dark: 0x98989D),
        linkColor: Color(hex: 0x0A84FF),
        headerText: .white,
        useAppIconColorForHeader: true,
        headerColors: [
            .text: Color(hex: 0x5E5CE6),
            .link: Color(hex: 0x0A84FF),
            .color: Color(hex: 0xFF9300),
            .image: Color(hex: 0x30D158),
            .file: Color(hex: 0x8E8E93),
        ]
    )

    static let midnight = Theme(
        appearance: .darkAqua,
        panelMaterial: .hudWindow,
        panelTint: Color(hex: 0x0B1020, opacity: 0.6),
        panelCornerRadius: 18,
        searchBackground: Color(hex: 0x151B2E),
        searchText: Color(hex: 0xE2E8F0),
        tabText: Color(hex: 0x94A3B8),
        tabSelectedBackground: Color(hex: 0x22D3EE),
        tabSelectedText: Color(hex: 0x0B1020),
        cardBackground: Color(hex: 0x151B2E),
        cardBorder: Color(hex: 0x27304A),
        cardCornerRadius: 14,
        selectionBorder: Color(hex: 0x22D3EE),
        primaryText: Color(hex: 0xE2E8F0),
        secondaryText: Color(hex: 0x64748B),
        linkColor: Color(hex: 0x38BDF8),
        headerText: Color(hex: 0x0B1020),
        useAppIconColorForHeader: false,
        headerColors: [
            .text: Color(hex: 0xA78BFA),
            .link: Color(hex: 0x22D3EE),
            .color: Color(hex: 0xF472B6),
            .image: Color(hex: 0x34D399),
            .file: Color(hex: 0xFBBF24),
        ]
    )

    static let sunset = Theme(
        appearance: .aqua,
        panelMaterial: .popover,
        panelTint: Color(hex: 0xFFF4E6, opacity: 0.55),
        panelCornerRadius: 22,
        searchBackground: .white,
        searchText: Color(hex: 0x431407),
        tabText: Color(hex: 0x9A3412),
        tabSelectedBackground: Color(hex: 0xF97316),
        tabSelectedText: .white,
        cardBackground: .white,
        cardBorder: Color(hex: 0xFED7AA),
        cardCornerRadius: 18,
        selectionBorder: Color(hex: 0xEA580C),
        primaryText: Color(hex: 0x431407),
        secondaryText: Color(hex: 0xC2410C),
        linkColor: Color(hex: 0xDB2777),
        headerText: .white,
        useAppIconColorForHeader: false,
        headerColors: [
            .text: Color(hex: 0xF97316),
            .link: Color(hex: 0xEC4899),
            .color: Color(hex: 0xEF4444),
            .image: Color(hex: 0xF59E0B),
            .file: Color(hex: 0x8B5CF6),
        ]
    )

    /// ✏️ Your own theme — change anything you like.
    static let custom: Theme = {
        var t = Theme.paste
        t.selectionBorder = Color(hex: 0x10B981)
        t.tabSelectedBackground = Color(hex: 0x10B981)
        t.useAppIconColorForHeader = false
        t.headerColors[.text] = Color(hex: 0x059669)
        return t
    }()
}

// MARK: - Theme selection

enum ThemePreset: String, CaseIterable, Identifiable {
    case paste, midnight, sunset, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paste: "Paste"
        case .midnight: "Midnight"
        case .sunset: "Sunset"
        case .custom: "Personalizado"
        }
    }

    var theme: Theme {
        switch self {
        case .paste: .paste
        case .midnight: .midnight
        case .sunset: .sunset
        case .custom: .custom
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    private static let key = "selectedTheme"

    @Published var preset: ThemePreset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: Self.key) }
    }

    var theme: Theme { preset.theme }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        preset = saved.flatMap(ThemePreset.init(rawValue:)) ?? .paste
    }
}

// MARK: - Color helpers

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: opacity))
    }

    /// A color that switches automatically between light and dark appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}
