// MAUI: Image.

/// Image's own properties - the half a `Style<Image>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
///
/// EMPTY, because an Image has nothing that is not `IImageElement`'s: `aspect`
/// and `isOpaque` are that interface's and live on `ImageElement`. The protocol
/// stays because every control has one, and because a property an Image alone
/// grows belongs here rather than on the tier.
public protocol ImageProperties: PropertyContainer {}

/// A picture from the application's resources.
///
///     Image("tab_list.png")
///         .aspect(.aspectFit)
///         .heightRequest(20)
///
/// The name is the one MAUI gives a file in `Resources/Images`, which for an SVG
/// is the PNG the build rasterizes it into: `tab_list.svg` is asked for as
/// `tab_list.png`, exactly as it would be in XAML.
///
/// **A file, never an address.** The host builds every source with
/// `ImageSource.FromFile`, so a name that looks like a url is looked for among
/// the resources like any other and simply is not found - where MAUI's own
/// string conversion would have fetched it.
///
/// Artwork that reads on one theme and not the other is drawn twice:
///
///     Image(light: "tab_list.png", dark: "tab_list_dark.png")
///
/// and the half in force is chosen as the value is written, so the picture
/// follows the system theme - the view that named it is rebuilt when that
/// changes. See Types/ImageSource.swift.
///
/// The source is the initializer argument because it is what an Image is for.
///
/// No PaddingElement: MAUI's Image has no Padding, and a modifier that compiles
/// into nothing is worse than no modifier.
public struct Image: View, ImageElement, ImageProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Image>` is written against.
    public init() {
        node = Node(type: .image)
    }

    /// A picture from `source`. Takes a plain string too, since an ImageSource
    /// is expressible by one: `Image("tab_list.png")`.
    public init(_ source: ImageSource) {
        node = Node(type: .image, props: [.source: source.propValue])
    }

    /// One picture per theme. MAUI: Source with an AppThemeBinding on it -
    /// here the half in force is picked as the value is written.
    public init(light: String, dark: String) {
        self.init(ImageSource(light: light, dark: dark))
    }

}
