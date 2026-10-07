// What a gallery's bars and windows can be.

import StateUI

// listing: Gallery.Looks
/// What a gallery's bars are.
enum BarLook: String, CaseIterable, PersistentValue {
    /// The platform's own bars, in its material and the user's accent.
    case platform

    /// Bars that paint nothing: what stands behind them shows.
    case clear

    /// The gallery's colour let through over the platform's material.
    case tinted

    /// The gallery's colour.
    case colour

    /// What the Appearance sample calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .clear: return "Clear"
        case .tinted: return "Material, tinted"
        case .colour: return "Colour"
        }
    }
}

/// What a gallery's windows show behind their pages.
enum WindowLook: String, CaseIterable, PersistentValue {
    /// The platform's own window.
    case platform

    /// A window that paints nothing: the desktop shows through it, sharp.
    case clear

    /// The window's material: the desktop shows through it, blurred.
    case material

    /// The window's material, in a light tint of the gallery's colour.
    case tintedMaterial

    /// The gallery's colour.
    case colour

    /// What the Appearance sample calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .clear: return "Clear"
        case .material: return "Material"
        case .tintedMaterial: return "Material, tinted"
        case .colour: return "Colour"
        }
    }

    /// Whether the look shows a material.
    var showsMaterial: Bool {
        self == .material || self == .tintedMaterial
    }

    /// Whether the look shows a colour.
    var showsColour: Bool {
        self == .tintedMaterial || self == .colour
    }

    /// What the window shows behind everything it draws: the desktop through
    /// `material`, where the look is a material; nil else.
    func backdrop(_ material: Material) -> Backdrop? {
        self == .material || self == .tintedMaterial ? .material(material) : nil
    }

    /// What the window shows behind its pages, in `accent` - the system's
    /// accent being `system`; nil for the platform's own.
    func background(in accent: AccentChoice, system: Color) -> Color? {
        switch self {
        case .platform, .material: return nil
        case .clear: return .transparent
        case .tintedMaterial: return accent.tint(system: system)
        case .colour: return accent.color(system: system)
        }
    }
}

/// The look the gallery wears in one theme: its bars and what its windows
/// show behind their pages, each in a colour of its own.
struct ThemeLook: Equatable {
    var bars: BarLook
    var barColour: AccentChoice
    var windows: WindowLook
    var windowColour: AccentChoice
    var material: Material
}

/// Where a theme's look stands in the session's style - one column of the
/// Appearance sample.
struct LookKeys {
    let bars: ReferenceWritableKeyPath<SessionStyle, BarLook>
    let barColour: ReferenceWritableKeyPath<SessionStyle, AccentChoice>
    let windows: ReferenceWritableKeyPath<SessionStyle, WindowLook>
    let windowColour: ReferenceWritableKeyPath<SessionStyle, AccentChoice>
    let material: ReferenceWritableKeyPath<SessionStyle, Material>

    /// The light theme's look.
    static var light: LookKeys {
        LookKeys(
            bars: \.lightBars, barColour: \.lightBarColour, windows: \.lightWindows,
            windowColour: \.lightWindowColour, material: \.lightMaterial)
    }

    /// The dark theme's look.
    static var dark: LookKeys {
        LookKeys(
            bars: \.darkBars, barColour: \.darkBarColour, windows: \.darkWindows,
            windowColour: \.darkWindowColour, material: \.darkMaterial)
    }
}
// listing: end
