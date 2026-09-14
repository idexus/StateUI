// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Image's own properties - the half a `Style<Image>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
///
/// One property of its own, `isAnimationPlaying`; `aspect` lives on
/// `ImageElement` because images and image buttons share it.
public protocol ImageProperties: PropertyContainer {}

extension ImageProperties {
    /// Whether an animated picture is running.
    ///
    /// For a source that HAS frames - a GIF, an animated WebP - and nothing at
    /// all for a still one. It is a property rather than an act, so a paused
    /// animation is a state the tree describes and a rebuild cannot lose.
    public func isAnimationPlaying(_ value: Bool) -> Modified {
        setValue(.isAnimationPlaying, .bool(value))
    }
}

/// A picture from the application's resources.
///
///     Image("tab_list.png")
///         .aspect(.aspectFit)
///         .heightRequest(20)
///
/// The name is a file among the application's image resources, and artwork
/// kept as an SVG is asked for by its PNG name: `tab_list.svg` is asked for as
/// `tab_list.png`.
///
/// **A file, never an address.** The host looks every source up among the
/// application's resources, so a name that looks like a url is looked for
/// there like any other and simply is not found.
///
/// Artwork that reads on one theme and not the other is drawn twice:
///
///     Image(light: "tab_list.png", dark: "tab_list_dark.png")
///
/// and both halves travel to the differ, which picks the one the theme asks
/// for as it builds the view - so the picture follows the system theme, and a
/// theme change builds again only the views wearing a pair. See
/// Types/ImageSource.swift.
///
/// The source is the initializer argument because it is what an Image is for.
///
/// No PaddingElement: an Image has no padding, and a modifier that compiles
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

    /// One picture per theme: both halves go on the node, and the differ picks
    /// one as it builds the view.
    public init(light: String, dark: String) {
        self.init(ImageSource(light: light, dark: dark))
    }

}
