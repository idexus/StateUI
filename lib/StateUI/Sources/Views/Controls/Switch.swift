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

/// An on/off toggle.
///
///     Switch($soundOn)
///         .tint(.green)
///
/// Given a binding it shows the value and writes every flip back. Given a plain
/// `Bool` - or nothing plus `.isOn(_:)` - it shows that and reports
/// nothing, so `.onToggled` is how the flip gets anywhere.
///
/// A `CheckBox` asks the same question in the shape a form uses; a
/// `RadioButton` is what to reach for once there are more than two answers.
public struct Switch: View, TintElement, SwitchProperties {
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
    public init(_ isOn: Binding<Bool>) {
        self = Switch().isOn(isOn)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows what the state holds and writes back what is flipped,
    /// with no view rebuilt for it.
    ///
    ///     @State private var on = false
    ///
    ///     Switch($on)
    ///
    /// - Parameter value: the state shown, and written back into as the user
    ///   flips it.
    /// - Returns: the switch, wearing and reporting that value.
    public func isOn(_ value: Binding<Bool>) -> Modified {
        value.image == nil
            ? described(SwitchContract.isOn.token, value, on: SwitchContract.toggled.token)
            : plain(SwitchContract.isOn.token, by: value, mode: .inOut)
    }

    // MARK: Events

    /// Fires when it is flipped, with the way it was flipped to. Runs after a
    /// binding's write.
    public func onToggled(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        onEvent(SwitchContract.toggled, handler)
    }
}
