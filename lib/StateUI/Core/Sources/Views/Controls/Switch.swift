// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Switch`'s own properties, shared by the control and its `Style<Switch>`.
public protocol SwitchProperties: PropertyContainer {}

extension SwitchProperties {
    /// Which way it is thrown - true for on. Usually given in the initializer.
    public func isOn(_ value: Bool) -> Modified {
        setValue(SwitchContract.isOn, value)
    }
}

/// An on/off toggle, and the words it says beside it.
///
///     Switch($wifi).text("Wi-Fi")
///         .tint(.green)
///
/// Given a binding it shows the value and writes every flip back. Given a plain
/// `Bool` - or nothing plus `.isOn(_:)` - it shows that and reports
/// nothing, so `.onToggled` is how the flip gets anywhere.
///
/// Its words are its own: a tap on them flips it, and a screen reader names
/// the switch by them. A `CheckBox` asks the same question in the shape a
/// form uses; a `Picker` presented as radio buttons
/// (`.presentation(.radio)`) is what to reach for once there are more than two
/// answers.
public struct Switch: ElementView, TextualElement, TintElement, SwitchProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Switch>` is written against, and what
    /// `.isOn(_:)` plus `.onToggled` build on.
    public init() {
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

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows what the state holds and writes back what is flipped,
    /// with no view rebuilt for it.
    ///
    ///     @State private var on = false
    ///
    ///     Switch($on)
    ///
    /// - Parameter state: the state shown, and written back into as the user
    ///   flips it.
    /// - Returns: the switch, wearing and reporting that value.
    public func isOn(_ state: Binding<Bool>) -> Modified {
        state.image == nil
            ? described(SwitchContract.isOn.token, state, on: SwitchContract.toggled.token)
            : plain(SwitchContract.isOn.token, by: state, mode: .inOut)
    }

    // MARK: Events

    /// Fires when it is flipped, with the way it was flipped to. Runs after a
    /// binding's write.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        onEvent(SwitchContract.toggled, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(gate: some Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        onEvent(SwitchContract.toggled, gate: gate, handler)
    }
}
