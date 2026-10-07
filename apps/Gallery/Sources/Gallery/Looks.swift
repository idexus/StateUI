// What a gallery's bars, window and sidebar can be.

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

/// What one surface of the gallery is made of - its window, its sidebar, its
/// sidebar sliding over the page.
enum SurfaceMaterial: String, CaseIterable, PersistentValue {
    /// The platform's own.
    case platform

    /// Nothing: what stands behind shows through, sharp.
    case clear

    /// A blur: what stands behind shows through, blurred.
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

    /// Whether the surface shows a blur.
    var showsBlur: Bool {
        self == .blur || self == .tintedBlur
    }

    /// Whether the surface shows a colour.
    var showsColour: Bool {
        self == .tintedBlur || self == .colour
    }
}

/// One surface's look: what it is made of, in which colour, how thick a blur.
struct SurfaceLook: Equatable {
    var material: SurfaceMaterial
    var colour: AccentChoice
    var blur: Blur

    /// The blurs offered, thinnest first.
    static let blurs: [Blur] = [.ultraThin, .thin, .regular, .thick, .ultraThick]

    /// The platform's own surface - the gallery's own colour, or a thick
    /// blur, once one is chosen.
    static let platform = SurfaceLook(material: .platform, colour: .gallery, blur: .thick)

    /// The gallery's own colour for the part it paints.
    static let galleryOwn = SurfaceLook(material: .colour, colour: .gallery, blur: .thick)

    /// The material `surface` is: its blur where it is one, tinted in its
    /// colour - the system's accent being `system` - where it is tinted, the
    /// colour where it is one; nil for the platform's own.
    func material(system: Color, for surface: GallerySurface) -> Material? {
        switch material {
        case .platform: return nil
        case .clear: return .color(.transparent)
        case .blur: return .blur(blur)
        case .tintedBlur: return .blur(blur.tint(colour.tint(system: system, for: surface)))
        case .colour: return .color(colour.color(system: system, for: surface))
        }
    }
}

/// The look the gallery wears in one theme: its bars, and what its window, its
/// sidebar and its sidebar sliding over the page are made of. Kept as one line
/// of words, so a scene keeps a theme's whole look under one key.
struct ThemeLook: Equatable, RawRepresentable, PersistentValue {
    var bars: BarLook
    var barColour: AccentChoice
    var window: SurfaceLook
    var sidebar: SurfaceLook
    var flyout: SurfaceLook

    init(bars: BarLook, barColour: AccentChoice, window: SurfaceLook, sidebar: SurfaceLook, flyout: SurfaceLook) {
        (self.bars, self.barColour, self.window, self.sidebar, self.flyout) = (bars, barColour, window, sidebar, flyout)
    }

    /// The light theme's look the gallery opens in: clear bars, and the
    /// platform's own window and sidebar.
    static let light = ThemeLook(
        bars: .clear, barColour: .gallery, window: .platform, sidebar: .platform, flyout: .platform)

    /// The dark theme's look the gallery opens in, each platform's best: a
    /// window of the desktop blurred - in the gallery's violet on a Mac and on
    /// GNOME, plain under Windows' own bars - its sidebar letting it through.
    static var dark: ThemeLook {
        let violet = { (blur: Blur) in SurfaceLook(material: .tintedBlur, colour: .violet, blur: blur) }
        #if APPKIT
        return ThemeLook(
            bars: .clear, barColour: .violet, window: violet(.thick),
            sidebar: SurfaceLook(material: .clear, colour: .violet, blur: .thick), flyout: .platform)
        #elseif WINUI
        return ThemeLook(
            bars: .platform, barColour: .violet,
            window: SurfaceLook(material: .blur, colour: .violet, blur: .ultraThick),
            sidebar: .platform, flyout: .platform)
        #elseif GTK
        return ThemeLook(
            bars: .clear, barColour: .violet, window: violet(.ultraThick),
            sidebar: SurfaceLook(material: .platform, colour: .violet, blur: .ultraThick), flyout: .platform)
        #elseif UIKIT
        return ThemeLook(
            bars: .clear, barColour: .gallery, window: violet(.thick), sidebar: .galleryOwn, flyout: .galleryOwn)
        #else
        return ThemeLook(
            bars: .clear, barColour: .gallery, window: violet(.thick), sidebar: .platform, flyout: .galleryOwn)
        #endif
    }

    /// The look as words: the bars and their colour, then each surface's
    /// material, colour and blur.
    var rawValue: String {
        ([bars.rawValue, barColour.rawValue] + [window, sidebar, flyout].flatMap { surface in
            [surface.material.rawValue, surface.colour.rawValue,
             String(SurfaceLook.blurs.firstIndex(of: surface.blur) ?? 0)]
        }).joined(separator: " ")
    }

    /// The look its words say; nil for words another version wrote.
    init?(rawValue: String) {
        let words = rawValue.split(separator: " ").map(String.init)
        guard words.count == 11, let bars = BarLook(rawValue: words[0]),
              let barColour = AccentChoice(rawValue: words[1])
        else { return nil }
        var surfaces: [SurfaceLook] = []
        for at in stride(from: 2, to: 11, by: 3) {
            guard let material = SurfaceMaterial(rawValue: words[at]), let colour = AccentChoice(rawValue: words[at + 1]),
                  let blur = Int(words[at + 2]), SurfaceLook.blurs.indices.contains(blur)
            else { return nil }
            surfaces.append(SurfaceLook(material: material, colour: colour, blur: SurfaceLook.blurs[blur]))
        }
        self.init(bars: bars, barColour: barColour, window: surfaces[0], sidebar: surfaces[1], flyout: surfaces[2])
    }
}
// listing: end
