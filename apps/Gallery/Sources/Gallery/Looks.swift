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

    /// What a gallery opens in: on a Mac the window's material in a light
    /// tint, elsewhere the platform's own.
    static var opening: WindowLook {
        #if APPKIT
        .tintedMaterial
        #else
        .platform
        #endif
    }

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

    /// Whether the desktop shows through the window, blurred.
    var isTranslucent: Bool {
        self == .material || self == .tintedMaterial
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
// listing: end
