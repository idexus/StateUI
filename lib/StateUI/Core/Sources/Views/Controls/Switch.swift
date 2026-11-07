// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An on/off toggle, and the words it says beside it.
///
///     Switch("Wi-Fi", isOn: $wifi)
///         .tint(.green)
///
/// Given a binding it shows the value and writes every flip back. Given a plain
/// `Bool` it shows that and reports nothing, so `.onToggled` is how the flip
/// gets anywhere.
///
/// Its words are its own: a tap on them flips it, and a screen reader names
/// the switch by them. A `CheckBox` asks the same question in the shape a
/// form uses; a `Picker` presented as radio buttons
/// (`.presentation(.radio)`) is what to reach for once there are more than two
/// answers.
public struct Switch: ElementView, TextualElement, TintElement, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: SwitchContract.self)
    }

    /// A switch showing `isOn`. One-way: the flip goes nowhere without
    /// `.onToggled`.
    public init(_ isOn: Bool) {
        node = Node(contract: SwitchContract.self)
        node.write(SwitchContract.isOn, isOn)
    }

    /// Two-way: shows what the binding holds, and writes back what is flipped.
    public init(_ state: Binding<Bool>) {
        self = Switch().isOn(state)
    }

    /// A switch with its words beside it, on or off. One-way: the flip goes nowhere without `.onToggled`.
    public init(_ text: String, isOn: Bool) {
        self = Switch(isOn).text(text)
    }

    /// A switch with its words beside it, two-way: shows what the binding holds, and writes back what is flipped.
    ///
    ///     Switch("Wi-Fi", isOn: $wifi)
    public init(_ text: String, isOn state: Binding<Bool>) {
        self = Switch(state).text(text)
    }

    /// Whether it is on.
    func isOn(_ value: Bool) -> Modified {
        setValue(SwitchContract.isOn, value)
    }

    /// Whether it is on, from a state carried both ways.
    func isOn(_ state: Binding<Bool>) -> Modified {
        plain(SwitchContract.isOn.token, by: state, mode: .inOut)
    }

    // MARK: Events

    /// Fires when it is flipped, with the way it was flipped to. Runs after a
    /// binding's write.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        onEvent(SwitchContract.toggled, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        onEvent(SwitchContract.toggled, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onToggled(gate: Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        onEvent(SwitchContract.toggled, gate: gate, handler)
    }
}
