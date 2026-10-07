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
        case .tinted: return "Tinted"
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

    /// A blur: the desktop shows through the window, blurred.
    case blur

    /// A blur in a light tint of the gallery's colour.
    case tintedBlur

    /// The gallery's colour.
    case colour

    /// What the Appearance sample calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .clear: return "Clear"
        case .blur: return "Blur"
        case .tintedBlur: return "Blur, tinted"
        case .colour: return "Colour"
        }
    }

    /// Whether the look shows a blur.
    var showsBlur: Bool {
        self == .blur || self == .tintedBlur
    }

    /// Whether the look shows a colour.
    var showsColour: Bool {
        self == .tintedBlur || self == .colour
    }

    /// What the window is made of: `blur` where the look is a blur, tinted in
    /// `accent` - the system's accent being `system` - where it is tinted, the
    /// colour where it is one; nil for the platform's own.
    func material(_ blur: Blur, in accent: AccentChoice, system: Color) -> Material? {
        switch self {
        case .platform: return nil
        case .clear: return .color(.transparent)
        case .blur: return .blur(blur)
        case .tintedBlur: return .blur(blur.tint(accent.tint(system: system)))
        case .colour: return .color(accent.color(system: system))
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
    var blur: Blur
}

/// Where a theme's look stands in the session's style - one column of the
/// Appearance sample.
struct LookKeys {
    let bars: ReferenceWritableKeyPath<SessionStyle, BarLook>
    let barColour: ReferenceWritableKeyPath<SessionStyle, AccentChoice>
    let windows: ReferenceWritableKeyPath<SessionStyle, WindowLook>
    let windowColour: ReferenceWritableKeyPath<SessionStyle, AccentChoice>
    let blur: ReferenceWritableKeyPath<SessionStyle, Blur>

    /// The light theme's look.
    static var light: LookKeys {
        LookKeys(
            bars: \.lightBars, barColour: \.lightBarColour, windows: \.lightWindows,
            windowColour: \.lightWindowColour, blur: \.lightBlur)
    }

    /// The dark theme's look.
    static var dark: LookKeys {
        LookKeys(
            bars: \.darkBars, barColour: \.darkBarColour, windows: \.darkWindows,
            windowColour: \.darkWindowColour, blur: \.darkBlur)
    }
}
// listing: end
