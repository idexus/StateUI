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

    /// The platform's glass: what stands behind bent and lit through it.
    case glass

    /// The platform's glass in a tint of the gallery's colour.
    case tintedGlass

    /// The gallery's colour.
    case colour

    /// What the Appearance sample calls it.
    var name: String {
        switch self {
        case .platform: return "The platform's own"
        case .clear: return "Clear"
        case .blur: return "Blur"
        case .tintedBlur: return "Blur, tinted"
        case .glass: return "Glass"
        case .tintedGlass: return "Glass, tinted"
        case .colour: return "Colour"
        }
    }

    /// Whether the surface shows a blur.
    var showsBlur: Bool {
        self == .blur || self == .tintedBlur
    }

    /// Whether the surface shows a colour.
    var showsColour: Bool {
        self == .tintedBlur || self == .tintedGlass || self == .colour
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
        case .glass: return .glass(.regular)
        case .tintedGlass: return .glass(.regular.tint(colour.tint(system: system, for: surface)))
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

    /// The dark theme's look the gallery opens in: on Windows a window of the
    /// desktop blurred in the gallery's violet, its sidebar letting it
    /// through; on the Mac and GNOME a thin blur of the desktop in the
    /// gallery's own colour, made from that window, its sidebar the
    /// platform's glass in it; on the iPad and the iPhone those colours, the
    /// sidebar the same glass; on the Web those colours.
    static var dark: ThemeLook {
        let violet = { (blur: Blur) in SurfaceLook(material: .tintedBlur, colour: .violet, blur: blur) }
        #if WINUI
        return ThemeLook(
            bars: .platform, barColour: .violet, window: violet(.thick), sidebar: .platform, flyout: .platform)
        #elseif APPKIT || GTK
        return ThemeLook(
            bars: .clear, barColour: .gallery, window: SurfaceLook(material: .tintedBlur, colour: .gallery, blur: .regular),
            sidebar: SurfaceLook(material: .tintedGlass, colour: .gallery, blur: .thick), flyout: .galleryOwn)
        #elseif UIKIT
        let glass = SurfaceLook(material: .tintedGlass, colour: .gallery, blur: .thick)
        return ThemeLook(bars: .clear, barColour: .gallery, window: .galleryOwn, sidebar: glass, flyout: glass)
        #elseif WEB
        return ThemeLook(
            bars: .clear, barColour: .gallery, window: .galleryOwn, sidebar: .galleryOwn, flyout: .galleryOwn)
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

/// A theme's look as the user chose it: the gallery's own, or one composed in
/// the Appearance sample. A scene keeps the CHOICE - the gallery's own is drawn
/// afresh at every start, as this version of the gallery makes it, never kept
/// as what it was when the scene was.
enum LookChoice: Equatable, RawRepresentable, PersistentValue {
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
