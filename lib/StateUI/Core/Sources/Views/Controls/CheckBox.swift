// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `CheckBox`'s own properties, shared by the control and its
/// `Style<CheckBox>`.
public protocol CheckBoxProperties: PropertyContainer {}

extension CheckBoxProperties {
    /// Whether the box is ticked. Usually given in the initializer.
    public func isOn(_ value: Bool) -> Modified {
        setValue(CheckBoxContract.isOn, value)
    }
}

/// A box that is ticked or not, and the words it says beside it.
///
///     @State private var agreed = false
///     …
///     CheckBox($agreed).text("I agree to the terms")
///
/// Given a binding it shows what the binding holds and writes every tick back.
/// Given a plain `Bool` it only shows: `.onToggled` is then the one way
/// a tick reaches anywhere.
///
/// Its words are its own: a tap on them ticks the box, and a screen reader
/// names the box by them.
public struct CheckBox: ElementView, TextualElement, TintElement, CheckBoxProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<CheckBox>` is written against.
    public init() {
        node = Node(contract: CheckBoxContract.self)
    }

    /// A box that is ticked or not. One-way: what is ticked goes nowhere
    /// without `.onToggled`.
    public init(_ isOn: Bool) {
        node = Node(contract: CheckBoxContract.self)
        node.write(CheckBoxContract.isOn, isOn)
    }

    /// Two-way: shows what the binding holds, and writes back what is ticked.
    public init(_ state: some TwoWay<Bool>) {
        self = CheckBox().isOn(state)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows what the state holds and writes back what is ticked,
    /// with no view rebuilt for it.
    ///
    /// - Parameter state: the state shown, and written back into as the user
    ///   ticks it.
    /// - Returns: the box, wearing and reporting that value.
    public func isOn(_ state: some TwoWay<Bool>) -> Modified {
        guard let whole = state.whole else {
            return described(CheckBoxContract.isOn.token, state, on: CheckBoxContract.toggled.token)
        }

        return plain(CheckBoxContract.isOn.token, by: whole, mode: .inOut)
    }

    // MARK: Events

    /// Fires when it is ticked or unticked, with the new value. Runs after a
    /// binding's write, if there is one.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        onEvent(CheckBoxContract.toggled, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        onEvent(CheckBoxContract.toggled, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onToggled(gate: Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        onEvent(CheckBoxContract.toggled, gate: gate, handler)
    }
}
