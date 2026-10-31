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
public struct MenuToggle: Element, MenuItemElement {
    /// The node this entry describes.
    public var node: Node

    /// An entry captioned `text`, standing checked as `isOn` says. One-way:
    /// the turn goes nowhere without `.onToggled`.
    public init(_ text: String, isOn: Bool) {
        node = Node(contract: MenuToggleContract.self)
        node.write(MenuItemElementContract.text, text)
        node.write(MenuToggleContract.isOn, isOn)
    }

    /// An entry captioned `text`, standing checked as the state holds; choosing
    /// it turns the state over.
    ///
    /// The state is read as the entry is described, so a change describes the
    /// entry alone again: a menu is walked from the tree, never a channel of its own.
    /// Design: docs/design/host/pages.md#a-checked-entry
    public init(_ text: String, isOn: Binding<Bool>) {
        self.init(text, isOn: false)
        node.readsWhenDescribed { $0.write(MenuToggleContract.isOn, isOn.wrappedValue) }
        node.addHandler(MenuToggleContract.toggled.token) {
            if let turned = EventBuffer.current.value()?.bool { isOn.wrappedValue = turned }
        }
    }

    /// Fires when the user chooses it, with the way it turned to. Runs after
    /// the state's write.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        modified { $0.addHandler(MenuToggleContract.toggled, handler) }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        modified { $0.addHandler(MenuToggleContract.toggled, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onToggled(gate: Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        modified { $0.addHandler(MenuToggleContract.toggled, gate: gate, handler) }
    }

    /// Who this entry is among the menu's others, so it stays matched to itself
    /// when the entries around it come and go; without one it is matched by
    /// position.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.identify(value) }
    }
}
