// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Button's own properties - the half a `Style<Button>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ButtonProperties: PropertyContainer {}

extension ButtonProperties {
    /// What happens to a caption too long for the button.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(.lineBreak, value.propValue)
    }

    /// The picture beside the caption - a file among the application's image
    /// resources, by name; see `Image`. A button with an icon and no caption is
    /// `Button(icon:)`.
    ///
    ///     Button("Surprise me").icon("nav_surprise.png")
    public func icon(_ value: ImageSource) -> Modified {
        setValue(.icon, value.propValue)
    }

    /// Which side of the caption the icon stands on. `.leading`, the default,
    /// is the side a line of text starts from, so it follows the layout
    /// direction.
    ///
    ///     Button("Surprise me")
    ///         .icon("nav_surprise.png")
    ///         .iconPosition(.leading)
    ///         .iconSpacing(8)
    public func iconPosition(_ value: IconPosition) -> Modified {
        setValue(.iconPosition, value.propValue)
    }

    /// The gap between the icon and the caption, in device units.
    public func iconSpacing(_ value: Double) -> Modified {
        setValue(.iconSpacing, .number(value))
    }
}

/// A button with a caption, and a handler for the press.
///
///     @State private var counter = 0
///     …
///     Button("Increment")
///         .background(.cornflowerBlue)
///         .cornerRadius(8)
///         .onClicked { counter += 1 }
///
/// The caption goes in the initializer because it is what a button IS;
/// everything else - the colours, the outline, the picture beside the words -
/// is a modifier.
///
/// A handler may `await`: it runs on this library's own main thread and the
/// interface goes on being described while it is suspended, so
/// `.onClicked { items = try await load() }` needs nothing around it.
public struct Button: View, TextElement, FontElement, PaddingElement, BorderElement, ImageElement,
    ButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Button>` is written against.
    public init() {
        node = Node(type: .button)
    }

    /// A button whose content is an icon, with no caption: the picture is what
    /// gives it its purpose.
    ///
    ///     Button(icon: "trash.png")
    ///     Button(icon: ImageSource(light: "trash.png", dark: "trash_dark.png"))
    ///
    /// The same button as one with a caption - the same border, corner radius
    /// and pressed state - with `.aspect` for how its picture fills it.
    public init(icon: ImageSource) {
        node = Node(type: .button, props: [.icon: icon.propValue])
    }

    /// A button captioned `text`.
    public init(_ text: String) {
        node = Node(type: .button, props: [.text: .string(text)])
    }

    /// The same spelling over a state the host carries: a caption written by the host when the
    /// bytes change, at no render.
    ///
    /// - Parameter text: the state the caption is read from.
    public init(_ text: Binding<String>) {
        self = Button().text(text)
    }

    // MARK: Properties

    // MARK: Events

    /// Runs when the button is pressed AND released on it - the ordinary one.
    /// A second `.onClicked` runs beside the first, like every typed event
    /// modifier.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        addHandler(.clicked, handler)
    }

    /// Runs the moment the finger goes down, before it is lifted.
    public func onPressed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.pressed, handler)
    }

    /// Runs when the finger is lifted, wherever it ends up - unlike `onClicked`,
    /// which needs it lifted on the button.
    public func onReleased(_ handler: @escaping EventHandler) -> Self {
        addHandler(.released, handler)
    }
}

/// Which side of a button's caption its picture is on.
///
/// Its numbers are this wire's own - the rule at the head of
/// Types/Enums.swift, which every closed vocabulary on this wire follows.
public enum IconPosition: Int32, Sendable {
    /// Before the words, on the side a line starts from - the default.
    case leading = 0

    /// Above them.
    case top = 1

    /// After them, on the side a line ends.
    case trailing = 2

    /// Below them.
    case bottom = 3

    var propValue: PropValue { .enumeration(rawValue) }
}
