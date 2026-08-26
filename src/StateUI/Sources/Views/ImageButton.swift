// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: ImageButton.

/// ImageButton's own properties - the half a `Style<ImageButton>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
///
/// EMPTY, because an ImageButton has nothing of its own: `aspect` and
/// `isOpaque` are `ImageElement`'s, the padding and the border belong to their
/// own mixins, and the picture goes in the initializer. The protocol stays
/// because every control has one, and because a property an ImageButton alone
/// grows belongs here rather than on a tier.
public protocol ImageButtonProperties: PropertyContainer {}

extension ImageButtonProperties {
}

/// A button that is a picture, with no caption at all.
///
///     ImageButton("nav_media.png")
///         .aspect(.aspectFit)
///         .padding(12)
///         .onClicked { shown.toggle() }
///
/// MAUI's ImageButton is a Button with a Source instead of Text - not an Image
/// with a tap recognizer on it, which is the other way to say something like
/// this and gives no pressed state, no border and no corner radius.
///
/// The artwork is what gives it its purpose, so it goes in the initializer, and
/// it can be drawn once per theme like any other picture:
///
///     ImageButton(light: "nav_media.png", dark: "nav_media_dark.png")
///
/// The artwork comes from the application's resources and nowhere else - a name
/// that looks like a url is looked for among them too. See `Image`.
///
/// No TextElement and no FontElement: there is no text on one.
public struct ImageButton: View, PaddingElement, BorderElement, ImageElement,
    ImageButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ImageButton>` is written against.
    public init() {
        node = Node(type: .imageButton)
    }

    /// A button showing `source`. Takes a plain string too, since an ImageSource
    /// is expressible by one: `ImageButton("nav_media.png")`.
    public init(_ source: ImageSource) {
        node = Node(type: .imageButton, props: [.source: source.propValue])
    }

    /// One picture per theme. MAUI: Source with an AppThemeBinding on it -
    /// here the half in force is picked as the value is written.
    public init(light: String, dark: String) {
        self.init(ImageSource(light: light, dark: dark))
    }

    // MARK: Properties

    // MARK: Events

    /// Runs when the button is pressed AND released on it - the ordinary one.
    /// A second `.onClicked` runs beside the first, like every typed event
    /// modifier. MAUI: ImageButton.Clicked.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        addHandler(.clicked, handler)
    }

    /// Runs the moment the finger goes down, before it is lifted.
    /// MAUI: ImageButton.Pressed.
    public func onPressed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.pressed, handler)
    }

    /// Runs when the finger is lifted, wherever it ends up - unlike `onClicked`,
    /// which needs it lifted on the button. MAUI: ImageButton.Released.
    public func onReleased(_ handler: @escaping EventHandler) -> Self {
        addHandler(.released, handler)
    }
}
