// What a gallery's bars, window and sidebar can be.

import StateUI

// listing: Gallery.Looks
/// What one surface of the gallery is made of - its bars, its window, its
/// sidebar, its sidebar sliding over the page.
enum SurfaceMaterial: String, CaseIterable, Codable {
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

    /// The gallery's gradient, violet into orange - offered for the bars.
    case gradient

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
        case .gradient: return "Gradient"
        }
    }

    /// The materials `surface` offers: the gradient on the bars alone.
    static func offered(on surface: GallerySurface) -> [SurfaceMaterial] {
        surface == .bar ? allCases : allCases.filter { $0 != .gradient }
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

    /// Where `blur` stands among the blurs offered - a thick one where it is none of them.
    static func place(of blur: Blur) -> Int {
        blurs.firstIndex(of: blur) ?? 3
    }

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
        case .gradient: return Palette.onBrand
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
        case .gradient: return .gradient(Palette.identity)
        }
    }
}

/// The look the gallery wears in one theme: its bars, and what its window, its
/// sidebar and its sidebar sliding over the page are made of. A scene keeps
/// each of its fields under a key of its own (SessionStyle).
struct ThemeLook: Equatable {
    var bars: SurfaceLook
    var window: SurfaceLook
    var sidebar: SurfaceLook
    var sidebarOverlay: SurfaceLook

    init(bars: SurfaceLook, window: SurfaceLook, sidebar: SurfaceLook, sidebarOverlay: SurfaceLook) {
        (self.bars, self.window, self.sidebar, self.sidebarOverlay) = (bars, window, sidebar, sidebarOverlay)
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
        return ThemeLook(bars: .clear, window: .platform, sidebar: sidebar, sidebarOverlay: .platform)
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
            sidebarOverlay: violet)
        #elseif APPKIT
        let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
        return ThemeLook(
            bars: .clear, window: SurfaceLook(material: .tintedBlur, color: .gallery, blur: .thick), sidebar: glass,
            sidebarOverlay: glass)
        #elseif UIKIT
        let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
        return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: glass, sidebarOverlay: glass)
        #else
        return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: .galleryOwn, sidebarOverlay: .galleryOwn)
        #endif
    }

}

// listing: end
