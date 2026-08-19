// MAUI: Button.

/// Button's own properties - the half a `Style<Button>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ButtonProperties: PropertyContainer {}

extension ButtonProperties {
    /// What happens to a caption too long for the button.
    /// MAUI: Button.LineBreakMode.
    public func lineBreakMode(_ value: LineBreakMode) -> Modified {
        setValue(.lineBreakMode, value.propValue)
    }

    /// A picture beside the caption - a file in the app's Resources/Images, by
    /// the name MAUI gives it once built. MAUI: Button.ImageSource.
    ///
    ///     Button("Surprise me").imageSource("nav_surprise.png")
    ///
    /// Where it sits and how far it stands off the words is
    /// `.contentLayout(_:spacing:)`. A button with a picture and NO caption is
    /// an `ImageButton` in MAUI, and that is the control to use for one.
    public func imageSource(_ value: ImageSource) -> Modified {
        setValue(.imageSource, value.propValue)
    }

    /// Which side of the caption the picture is on, and the gap between them.
    /// MAUI: Button.ContentLayout.
    ///
    ///     Button("Surprise me")
    ///         .imageSource("nav_surprise.png")
    ///         .contentLayout(.left, spacing: 8)
    ///
    /// It travels as the two parts it is - which side, then the gap - and the
    /// host builds the `ButtonContentLayout` from them.
    ///
    /// - Parameter spacing: The gap in device units. MAUI's own default is 10.
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

    // MARK: Properties

    // MARK: Events

    /// Runs when the button is pressed AND released on it - the ordinary one.
    /// A second `.onClicked` runs beside the first, like every typed event
    /// modifier. MAUI: Button.Clicked.
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        addHandler(.clicked, handler)
    }

    /// Runs the moment the finger goes down, before it is lifted.
    /// MAUI: Button.Pressed.
    public func onPressed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.pressed, handler)
    }

    /// Runs when the finger is lifted, wherever it ends up - unlike `onClicked`,
    /// which needs it lifted on the button. MAUI: Button.Released.
    public func onReleased(_ handler: @escaping EventHandler) -> Self {
        addHandler(.released, handler)
    }
}

/// Which side of a button's caption its picture is on.
/// MAUI: Button.ButtonContentLayout.ImagePosition.
///
/// Numbered here rather than there - the rule at the head of Types/Enums.swift,
/// which every closed vocabulary on this wire follows.
public enum ButtonContentPosition: Int32, Sendable {
    /// Before the words, which is MAUI's own default.
    case left = 0

    /// Above them.
    case top = 1

    /// After them.
    case right = 2

    /// Below them.
    case bottom = 3

    var propValue: PropValue { .enumeration(rawValue) }
}
