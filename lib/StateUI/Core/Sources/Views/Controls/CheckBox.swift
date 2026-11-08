// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A box that is ticked or not, and the words it says beside it.
///
///     @State private var agreed = false
///     …
///     CheckBox("I agree to the terms", isOn: $agreed)
///
/// Given a binding it shows what the binding holds and writes every tick back.
/// Given a plain `Bool` it only shows: `.onToggled` is then the one way
/// a tick reaches anywhere.
///
/// Its words are its own: a tap on them ticks the box, and a screen reader
/// names the box by them.
public struct CheckBox: ElementView, TextualElement, TintElement, FocusElement, ToggleElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: CheckBoxContract.self)
    }

    /// A box that is ticked or not. One-way: what is ticked goes nowhere
    /// without `.onToggled`.
    public init(_ isOn: Bool) {
        node = Node(contract: CheckBoxContract.self)
        node.write(ToggleElementContract.isOn, isOn)
    }

    /// Two-way: shows what the binding holds, and writes back what is ticked.
    public init(_ state: Binding<Bool>) {
        self = CheckBox().isOn(state)
    }

    /// A box with its words beside it, ticked or not. One-way: what is ticked goes nowhere without `.onToggled`.
    public init(_ text: String, isOn: Bool) {
        self = CheckBox(isOn).text(text)
    }

    /// A box with its words beside it, two-way: shows what the binding holds, and writes back what is ticked.
    ///
    ///     CheckBox("I agree to the terms", isOn: $agreed)
    public init(_ text: String, isOn state: Binding<Bool>) {
        self = CheckBox(state).text(text)
    }

    /// A box whose words are carried from a state, written by the host as they change, at no render; ticked or not.
    /// One-way: what is ticked goes nowhere without `.onToggled`.
    public init(_ state: Binding<String>, isOn: Bool) {
        self = CheckBox(isOn).text(state)
    }

    /// A box whose words are carried from a state, two-way: shows what the binding holds, and writes back what is
    /// ticked.
    ///
    ///     CheckBox($terms, isOn: $agreed)
    public init(_ state: Binding<String>, isOn: Binding<Bool>) {
        self = CheckBox(isOn).text(state)
    }

    /// Whether it is checked.
    func isOn(_ value: Bool) -> Modified {
        setValue(ToggleElementContract.isOn, value)
    }

    /// Whether it is checked, from a state carried both ways.
    func isOn(_ state: Binding<Bool>) -> Modified {
        plain(ToggleElementContract.isOn.token, by: state, mode: .inOut)
    }

}
