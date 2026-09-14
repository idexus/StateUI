// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Button's own properties - the half a `Style<Button>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ButtonProperties: PropertyContainer {}

extension ButtonProperties {
    /// What happens to a caption too long for the button.
    public func lineBreakMode(_ value: LineBreakMode) -> Modified {
        setValue(.lineBreakMode, value.propValue)
    }

    /// A picture beside the caption - a file among the application's image
    /// resources, by name; see `Image`.
    ///
    ///     Button("Surprise me").imageSource("nav_surprise.png")
    ///
    /// Where it sits and how far it stands off the words is
    /// `.contentLayout(_:spacing:)`. A button with a picture and NO caption is
    /// an `ImageButton`, and that is the control to use for one.
    public func imageSource(_ value: ImageSource) -> Modified {
        setValue(.imageSource, value.propValue)
    }

    /// Which side of the caption the picture is on, and the gap between them.
    ///
    ///     Button("Surprise me")
    ///         .imageSource("nav_surprise.png")
    ///         .contentLayout(.left, spacing: 8)
    ///
    /// It travels as the two parts it is - which side, then the gap - and the
    /// host places the picture from them.
    ///
    /// - Parameter spacing: The gap in device units, 10 unless said.
    public func contentLayout(_ position: ButtonContentPosition, spacing: Double = 10) -> Modified {
        setValue(.contentLayout, .values([position.propValue, .number(spacing)]))
    }
}

/// A button with a caption, and a handler for the press.
///
///     @State private var counter = 0
///     …
///     Button("Increment")
///         .backgroundColor(.cornflowerBlue)
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
public struct Button: View, TextElement, FontElement, PaddingElement, BorderElement,
    ButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Button>` is written against.
    public init() {
        node = Node(type: .button)
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
public enum ButtonContentPosition: Int32, Sendable {
    /// Before the words - the default.
    case left = 0

    /// Above them.
    case top = 1

    /// After them.
    case right = 2

    /// Below them.
    case bottom = 3

    var propValue: PropValue { .enumeration(rawValue) }
}
