// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An on/off toggle.

/// Switch's own properties - the half a `Style<Switch>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SwitchProperties: PropertyContainer {}

extension SwitchProperties {
    /// Which way it is thrown - true for on.
    ///
    /// `Switch(true)` and `Switch($soundOn)` both say this from their argument,
    /// so a modifier written beside one wins - and a binding goes on being
    /// written back to, which is how the two can then disagree.
    public func isOn(_ value: Bool) -> Modified {
        setValue(.isOn, .bool(value))
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
        node = Node(type: .`switch`)
    }

    /// A switch showing `isOn`. One-way: the flip goes nowhere without
    /// `.onToggled` - CheckBox's `CheckBox(true)` is the same pair.
    public init(_ isOn: Bool) {
        node = Node(type: .`switch`, props: [.isOn: .bool(isOn)])
    }

    /// Two-way: shows what the binding holds, and writes back what is flipped.
    public init(_ isOn: Binding<Bool>) {
        self = Switch().isOn(isOn)
    }

    /// Two-way: shows what the state holds and writes back what is flipped -
    /// and HANDED OVER, so the switch is no reader of the state. The host
    /// sets the toggle from the state and lands a flip on it as its own
    /// write, and what a flip COSTS is decided by who reads the state at
    /// build. A part of a state, or a binding made from closures, is one the
    /// host cannot carry: the tree shows it, and the closure that wrote it
    /// renders per flip.
    ///
    ///     @State private var on = false
    ///
    ///     Switch($on)
    ///
    /// - Parameter value: the state shown, and written back into as the
    ///   reader flips it.
    /// - Returns: the switch, wearing and reporting that value.
    public func isOn(_ value: Binding<Bool>) -> Modified {
        value.image == nil
            ? described(.isOn, value, on: .toggled)
            : plain(.isOn, by: value, mode: .inOut)
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when it is flipped, with the way it was flipped TO. Runs after a
    /// binding's write, if there is one.
    public func onToggled(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        addHandler(.toggled) {
            if let toggled = EventBuffer.current.value()?.bool {
                try await handler(toggled)
            }
        }
    }
}
