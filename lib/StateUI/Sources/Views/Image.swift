// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Image`'s own properties, shared by the control and its `Style<Image>`.
public protocol ImageProperties: PropertyContainer {}

extension ImageProperties {
    /// Whether an animated picture - a GIF, an animated WebP - is running.
    public func isAnimating(_ value: Bool) -> Modified {
        setValue(ImageContract.isAnimating, value)
    }
}

/// A picture from the application's resources.
///
///     Image("tab_list.png")
///         .aspect(.fit)
///         .height(20)
///
/// The name is a file among the application's image resources, and artwork
/// kept as an SVG is asked for by its PNG name: `tab_list.svg` is asked for as
/// `tab_list.png`.
///
/// A file, never an address: a name that looks like a url is looked for among
/// the resources like any other, and is not found.
///
/// Artwork that reads on one theme and not the other is drawn twice:
///
///     Image(light: "tab_list.png", dark: "tab_list_dark.png")
///
/// and the picture follows the system theme.
public struct Image: View, ImageElement, ImageProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Image>` is written against.
    public init() {
        node = Node(contract: ImageContract.self)
    }

    /// A picture from `source`. Takes a plain string too, since an ImageSource
    /// is expressible by one: `Image("tab_list.png")`.
    public init(_ source: ImageSource) {
        node = Node(contract: ImageContract.self)
        node.write(ImageContract.source, source)
    }

    /// One picture per theme, following the system theme.
    public init(light: String, dark: String) {
        self.init(ImageSource(light: light, dark: dark))
    }

}
