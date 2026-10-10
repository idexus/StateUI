// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Button`'s own properties, shared by the control and its `Style<Button>`.
public protocol ButtonProperties: PropertyContainer {}

extension ButtonProperties {
    /// What happens to a caption too long for the button.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(ButtonContract.lineBreak, value)
    }

    /// The picture beside the caption - a file among the application's image
    /// resources, by name; see `Image`. A button with an icon and no caption is
    /// `Button(icon:)`.
    ///
    ///     Button("Surprise me").icon("nav_surprise.png")
    public func icon(_ value: ImageSource) -> Modified {
        setValue(ButtonContract.icon, value)
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
        setValue(ButtonContract.iconPosition, value)
    }

    /// The gap between the icon and the caption, in device units.
    public func iconSpacing(_ value: Double) -> Modified {
        setValue(ButtonContract.iconSpacing, value)
    }
}

extension ButtonProperties where Self: View {
    /// The picture shown with the caption - the button's own, never the page's a view names with `.icon` where it
    /// stands for its page.
    ///
    ///     Button("Surprise me").icon("nav_surprise.png")
    public func icon(_ value: ImageSource) -> Modified {
        setValue(ButtonContract.icon, value)
    }
}

/// A button with a caption, and a handler for the press.
///
///     @State private var counter = 0
///     …
///     Button("Increment")
///         .background(.cornflowerBlue)
///         .shape(.roundedRectangle(8))
///         .onClicked { counter += 1 }
///
/// A handler runs on the main actor. One that awaits passes through a gate,
/// which says what a click does while it runs -
/// `.onClicked(gate: .ignoreWhileRunning) { items = try await load() }` - and
/// the interface goes on updating while it is suspended.
public struct Button: ElementView, TextualElement, FontElement, PaddingElement, BorderElement, ImageElement,
    ButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Button>` is written against.
    public init() {
        node = Node(contract: ButtonContract.self)
    }

    /// A button whose content is an icon, with no caption: the picture is what
    /// gives it its purpose.
    ///
    ///     Button(icon: "trash.png")
    ///     Button(icon: ImageSource(light: "trash.png", dark: "trash_dark.png"))
    ///
    /// The same button as one with a caption - the same outline, shape and
    /// pressed state - with `.contentMode` for how its picture fills it.
    public init(icon: ImageSource) {
        node = Node(contract: ButtonContract.self)
        node.write(ButtonContract.icon, icon)
    }

    /// A button captioned `text`.
    public init(_ text: String) {
        node = Node(contract: ButtonContract.self)
        node.write(TextualElementContract.text, text)
    }

    /// A button whose caption is carried from a state, written by the host as
    /// it changes, at no render.
    ///
    /// - Parameter text: the state the caption is read from.
    public init(_ text: Binding<String>) {
        self = Button().text(text)
    }

    // MARK: Events

    /// Runs when the button is pressed AND released on it - the ordinary one - all
    /// of it before the click is over. A second `.onClicked` runs beside the first,
    /// like every typed event modifier.
    public func onClicked(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(ButtonContract.clicked, handler)
    }

    /// Runs when the button is clicked, awaiting as it goes; its `gate` says what a
    /// click does while a run is under way.
    public func onClicked(gate: some Gate, _ handler: @escaping EventHandler) -> Self {
        onEvent(ButtonContract.clicked, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onClicked(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onClicked(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }

    /// Runs the moment a press begins, before it ends.
    public func onPressed(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(ButtonContract.pressed, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPressed(gate: some Gate, _ handler: @escaping EventHandler) -> Self {
        onEvent(ButtonContract.pressed, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPressed(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPressed(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }

    /// Runs when the press ends, wherever the pointer ends up - unlike
    /// `onClicked`, which needs it to end on the button.
    public func onReleased(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(ButtonContract.released, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onReleased(gate: some Gate, _ handler: @escaping EventHandler) -> Self {
        onEvent(ButtonContract.released, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onReleased(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onReleased(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }
}

/// Which side of a button's caption its picture is on.
public enum IconPosition: Int32, Sendable, HostRepresentable {
    /// Before the words, on the side a line starts from - the default.
    case leading = 0

    /// Above them.
    case top = 1

    /// After them, on the side a line ends.
    case trailing = 2

    /// Below them.
    case bottom = 3
}

extension IconPosition: StateChoice {}

extension Button {
    /// `iconPosition` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func iconPosition(_ state: Binding<IconPosition>) -> Modified {
        plain(.iconPosition, by: state)
    }

    /// `iconSpacing` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func iconSpacing(_ state: Binding<Double>) -> Modified {
        journey(.iconSpacing, by: state)
    }

    /// `lineBreak` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineBreak(_ state: Binding<LineBreak>) -> Modified {
        plain(ButtonContract.lineBreak.token, by: state)
    }
}
