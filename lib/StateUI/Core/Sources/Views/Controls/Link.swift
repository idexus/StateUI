// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Words that open an address - a page in the browser, a mail, a call - in
/// the application the system gives it, as `application.launch` does.
///
///     Link("Terms of use", address: "https://stateui.dev/terms")
///     Link("Write to us", address: "mailto:hello@stateui.dev")
///
/// It stands as the platform's own link where it has one, and as a button
/// drawn as one elsewhere; a screen reader names it by its words, and calls
/// it a link where the platform's accessibility has the role. An address the
/// platform will not open opens nothing. It stands at its words' size at the
/// start of its slot unless an alignment says otherwise.
public struct Link: ElementView, TextualElement, FocusElement, ClickElement {
    /// The node this control describes.
    public var node: Node

    /// A link saying `text` and opening `address`.
    public init(_ text: String, address: String) {
        node = Node(contract: LinkContract.self)
        node.write(TextElementContract.text, text)
        node.write(LinkContract.address, address)
    }

    /// A link saying `text` and opening the address a state holds, written by
    /// the host as it changes, at no render.
    ///
    /// - Parameters:
    ///   - text: its words.
    ///   - address: the state the address is read from.
    public init(_ text: String, address: Binding<String>) {
        node = Node(contract: LinkContract.self)
        node.write(TextElementContract.text, text)
        self = words(LinkContract.address, by: address)
    }

}
