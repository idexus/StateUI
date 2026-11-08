// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu standing checked or not - a mark beside it - for a
/// setting choosing it turns on and off.
///
///     MenuToggle("Show Ruler", isOn: $showsRuler)
///         .keyboardShortcut("r")
///
/// A menu shows its toggles' marks as the states hold them, and each choice
/// turns its state over; an entry that acts is a `MenuItem`.
public struct MenuToggle: Element, MenuItemElement, ToggleElement {
    /// The node this entry describes.
    public var node: Node

    /// An entry captioned `text`, standing checked as `isOn` says. One-way:
    /// the turn goes nowhere without `.onToggled`.
    public init(_ text: String, isOn: Bool) {
        node = Node(contract: MenuToggleContract.self)
        node.write(TextElementContract.text, text)
        node.write(ToggleElementContract.isOn, isOn)
    }

    /// An entry captioned `text`, standing checked as the state holds; choosing
    /// it turns the state over.
    ///
    /// The state is read as the entry is described, so a change describes the
    /// entry alone again: a menu is walked from the tree, never a channel of its own.
    /// Design: docs/design/host/pages.md#a-checked-entry
    public init(_ text: String, isOn: Binding<Bool>) {
        self.init(text, isOn: false)
        node.readsWhenDescribed { $0.write(ToggleElementContract.isOn, isOn.wrappedValue) }
        node.addHandler(ToggleElementContract.toggled.token) {
            if let turned = EventBuffer.current.value()?.bool { isOn.wrappedValue = turned }
        }
    }

    /// Who this entry is among the menu's others, so it stays matched to itself
    /// when the entries around it come and go; without one it is matched by
    /// position.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.identify(value) }
    }
}
