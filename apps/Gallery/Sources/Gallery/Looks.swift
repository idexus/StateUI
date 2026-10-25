// What a gallery's bars, window and sidebar can be.

import StateUI

// listing: Gallery.Looks
/// What one surface of the gallery is made of - its bars, its window, its
/// sidebar, its sidebar sliding over the page.
enum SurfaceMaterial: String, CaseIterable {
    /// The platform's own.
    case platform

    /// Nothing: what stands behind shows through, sharp.
    case clear

    /// A blur: what stands behind shows through, blurred.
    case blur

    /// A blur in a light tint of the gallery's color.
    case tintedBlur

    /// The platform's glass: what stands behind bent and lit through it.
    case glass

    /// The platform's glass in a tint of the gallery's color.
    case tintedGlass

    /// The gallery's color.
    case color

    /// What the Appearance sample calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .clear: return "Clear"
        case .blur: return "Blur"
        case .tintedBlur: return "Blur, tinted"
        case .glass: return "Glass"
        case .tintedGlass: return "Glass, tinted"
        case .color: return "Color"
        }
    }

    /// Whether the surface shows a blur.
    var showsBlur: Bool {
        self == .blur || self == .tintedBlur
    }

    /// Whether the surface shows a color.
    var showsColor: Bool {
        self == .tintedBlur || self == .tintedGlass || self == .color
    }
}

/// One surface's look: what it is made of, in which color, how thick a blur.
struct SurfaceLook: Equatable {
    var material: SurfaceMaterial
    var color: AccentChoice
    var blur: Blur

    /// The blurs offered, thinnest first.
    static let blurs: [Blur] = [.ultraThin, .thin, .regular, .thick, .ultraThick]

    /// The platform's own surface - the gallery's own color, or a thick
    /// blur, once one is chosen.
    static let platform = SurfaceLook(material: .platform, color: .gallery, blur: .thick)

    /// The gallery's own color for the part it paints.
    static let galleryOwn = SurfaceLook(material: .color, color: .gallery, blur: .thick)

    /// Bars that paint nothing: what stands behind them shows.
    static let clear = SurfaceLook(material: .clear, color: .gallery, blur: .thick)

    /// The words on a bar of this look: the brand's on the gallery's color
    /// where it carries none of the theme's, the theme's on anything else it
    /// paints or lets through; nil on the platform's own.
    var barWords: Color? {
        switch material {
        case .platform: return nil
        case .color: return color.carriesThemesWords ? Palette.text : Palette.onBrand
        default: return Palette.text
        }
    }

    /// The material `surface` is: its blur where it is one, tinted in its
    /// color - the system's accent being `system` - where it is tinted, the
    /// color where it is one; nil for the platform's own.
    func material(system: Color, for surface: GallerySurface) -> Material? {
        switch material {
        case .platform: return nil
        case .clear: return .color(.transparent)
        case .blur: return .blur(blur)
        case .tintedBlur: return .blur(blur.tint(color.tint(system: system, for: surface)))
        case .glass: return .glass(.regular)
        case .tintedGlass: return .glass(.regular.tint(color.tint(system: system, for: surface)))
        case .color: return .color(color.color(system: system, for: surface))
        }
    }
}

/// The look the gallery wears in one theme: its bars, and what its window, its
/// sidebar and its sidebar sliding over the page are made of. Kept as one line
/// of words, so a scene keeps a theme's whole look under one key.
struct ThemeLook: Equatable, RawRepresentable {
    var bars: SurfaceLook
    var window: SurfaceLook
    var sidebar: SurfaceLook
    var flyout: SurfaceLook

    init(bars: SurfaceLook, window: SurfaceLook, sidebar: SurfaceLook, flyout: SurfaceLook) {
        (self.bars, self.window, self.sidebar, self.flyout) = (bars, window, sidebar, flyout)
    }

    /// The light theme's look the gallery opens in: clear bars, and the
    /// platform's own window and sidebar - on the Mac the sidebar the
    /// platform's glass.
    static var light: ThemeLook {
        #if APPKIT
        let sidebar = SurfaceLook(material: .glass, color: .gallery, blur: .thick)
        #else
        let sidebar = SurfaceLook.platform
        #endif
        return ThemeLook(bars: .clear, window: .platform, sidebar: sidebar, flyout: .platform)
    }

    /// The dark theme's look the gallery opens in: on Windows a window of the
    /// desktop blurred in the gallery's violet, its sidebar letting it
    /// through, and over the page the page blurred in the same violet; on
    /// the Mac a thick blur of the desktop in the gallery's own color, made
    /// from that window, its sidebar the platform's glass in it; on the iPad
    /// and the iPhone those colors, the sidebar the same glass beside the
    /// page and over it; on the Web, GNOME and Android - which blur nothing
    /// behind a window - those colors, whole.
    static var dark: ThemeLook {
        #if WINUI
        let violet = SurfaceLook(material: .tintedBlur, color: .violet, blur: .thick)
        return ThemeLook(
            bars: SurfaceLook(material: .platform, color: .violet, blur: .thick), window: violet, sidebar: .platform,
            flyout: violet)
        #elseif APPKIT
        let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
        return ThemeLook(
            bars: .clear, window: SurfaceLook(material: .tintedBlur, color: .gallery, blur: .thick), sidebar: glass,
            flyout: glass)
        #elseif UIKIT
        let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
        return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: glass, flyout: glass)
        #else
        return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: .galleryOwn, flyout: .galleryOwn)
        #endif
    }

    /// The look as words: each surface's material, color and blur - the
    /// bars', the window's, the sidebar's and the flyout's.
    var rawValue: String {
        [bars, window, sidebar, flyout].flatMap { surface in
            [surface.material.rawValue, surface.color.rawValue,
             String(SurfaceLook.blurs.firstIndex(of: surface.blur) ?? 0)]
        }.joined(separator: " ")
    }

    /// The look its words say; nil for words another version wrote.
    init?(rawValue: String) {
        let words = rawValue.split(separator: " ").map(String.init)
        guard words.count == 12 else { return nil }
        var surfaces: [SurfaceLook] = []
        for at in stride(from: 0, to: 12, by: 3) {
            guard let material = SurfaceMaterial(rawValue: words[at]), let color = AccentChoice(rawValue: words[at + 1]),
                  let blur = Int(words[at + 2]), SurfaceLook.blurs.indices.contains(blur)
            else { return nil }
            surfaces.append(SurfaceLook(material: material, color: color, blur: SurfaceLook.blurs[blur]))
        }
        self.init(bars: surfaces[0], window: surfaces[1], sidebar: surfaces[2], flyout: surfaces[3])
    }
}

/// A theme's look as the user chose it: the gallery's own, or one composed in
/// the Appearance sample. A scene keeps the CHOICE - the gallery's own is drawn
/// afresh at every start, as this version of the gallery makes it, never kept
/// as what it was when the scene was.
enum LookChoice: Equatable, RawRepresentable, Codable {
    /// The look that suits the platform best: `ThemeLook.light` or `.dark`.
    case own

    /// A look the user put together.
    case composed(ThemeLook)

    /// The look the choice wears in a theme, `dark` or not.
    func look(dark: Bool) -> ThemeLook {
        switch self {
        case .own: return dark ? .dark : .light
        case .composed(let look): return look
        }
    }

    /// "own", or "composed" and the look's words.
    var rawValue: String {
        switch self {
        case .own: return "own"
        case .composed(let look): return "composed " + look.rawValue
        }
    }

    /// The choice its words say; nil for words another version wrote - a look
    /// kept whole - so the gallery starts in its own.
    init?(rawValue: String) {
        if rawValue == "own" {
            self = .own
        } else if rawValue.hasPrefix("composed "), let look = ThemeLook(rawValue: String(rawValue.dropFirst(9))) {
            self = .composed(look)
        } else {
            return nil
        }
    }
}
// listing: end
