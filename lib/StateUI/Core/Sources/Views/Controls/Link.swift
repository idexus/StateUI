// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Words that open an address - a page in the browser, a mail, a call - in
/// the application the system gives it, as `application.launch` does.
///
///     Link("Terms of use", destination: "https://stateui.dev/terms")
///     Link("Write to us", destination: "mailto:hello@stateui.dev")
///
/// It stands as the platform's own link where it has one, and as a button
/// drawn as one elsewhere; a screen reader names it by its words, and calls
/// it a link where the platform's accessibility has the role. An address the
/// platform will not open opens nothing.
public struct Link: ElementView, TextualElement, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Link>` is written against.
    public init() {
        node = Node(contract: LinkContract.self)
    }

    /// A link saying `text` and opening `destination`.
    public init(_ text: String, destination: String) {
        node = Node(contract: LinkContract.self)
        node.write(TextualElementContract.text, text)
        node.write(LinkContract.destination, destination)
    }

    /// A link saying `text` and opening the address a state holds, written by
    /// the host as it changes, at no render.
    ///
    /// - Parameters:
    ///   - text: its words.
    ///   - destination: the state the address is read from.
    public init(_ text: String, destination: Binding<String>) {
        node = Node(contract: LinkContract.self)
        node.write(TextualElementContract.text, text)
        self = words(LinkContract.destination, by: destination)
    }

    /// Runs as the user chooses the link, its address already on its way to
    /// the system. A second `.onClicked` runs beside the first, like every
    /// typed event modifier.
    public func onClicked(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(LinkContract.clicked, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what a click does
    /// while a run is under way.
    public func onClicked(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(LinkContract.clicked, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClicked(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(LinkContract.clicked, gate: gate, handler)
    }
}
