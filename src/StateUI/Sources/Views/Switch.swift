// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Switch.

/// Switch's own properties - the half a `Style<Switch>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SwitchProperties: PropertyContainer {}

extension SwitchProperties {
    /// Which way it is thrown - true for on. MAUI: Switch.IsToggled.
    ///
    /// `Switch(true)` and `Switch($soundOn)` both say this from their argument,
    /// so a modifier written beside one wins - and a binding goes on being
    /// written back to, which is how the two can then disagree.
    public func isToggled(_ value: Bool) -> Modified {
        setValue(.isToggled, .bool(value))
    }

    /// The colour of the track while it is ON. MAUI: Switch.OnColor.
    public func onColor(_ value: Color) -> Modified {
        setValue(.onColor, value.propValue)
    }

    /// The colour of the track while it is OFF. MAUI: Switch.OffColor.
    ///
    /// Left unwritten it is the platform's own, which is what most switches
    /// want - the off track is what tells one platform's switch from another's.
    public func offColor(_ value: Color) -> Modified {
        setValue(.offColor, value.propValue)
    }

    /// The colour of the knob that slides, whichever way it is thrown.
    /// MAUI: Switch.ThumbColor.
    public func thumbColor(_ value: Color) -> Modified {
        setValue(.thumbColor, value.propValue)
    }
}

/// An on/off toggle. MAUI: Switch.
///
///     Switch($soundOn)
///         .onColor(.green)
///
/// Given a binding it shows the value and writes every flip back. Given a plain
/// `Bool` - or nothing plus `.isToggled(_:)` - it shows that and reports
/// nothing, so `.onToggled` is how the flip gets anywhere.
///
/// A `CheckBox` asks the same question in the shape a form uses; a
/// `RadioButton` is what to reach for once there are more than two answers.
public struct Switch: View, SwitchProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Switch>` is written against, and what
    /// `.isToggled(_:)` plus `.onToggled` build on.
    public init() {
        node = Node(type: .`switch`)
    }

    /// A switch showing `isToggled`. One-way: the flip goes nowhere without
    /// `.onToggled` - CheckBox's `CheckBox(true)` is the same pair.
    public init(_ isToggled: Bool) {
        node = Node(type: .`switch`, props: [.isToggled: .bool(isToggled)])
    }

    /// Two-way: shows what the binding holds, and writes back what is flipped.
    public init(_ isToggled: Binding<Bool>) {
        self = Switch().isToggled(isToggled)
    }

    /// The same two-way value as `Switch($isToggled)`, written as a modifier.
    ///
    ///     Switch($level)
    ///     Switch().isToggled($level)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// - Parameter value: the state shown, and written back into as the reader
    ///   moves it.
    /// - Returns: the control, showing and reporting that value.
    public func isToggled(_ value: Binding<Bool>) -> Modified {
        modified {
            $0.props[.isToggled] = .bool(value.wrappedValue)
            $0.addHandler(.toggled) {
                if let moved = EventBuffer.current.value()?.bool {
                    value.wrappedValue = moved
                }
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when it is flipped, with the way it was flipped TO - MAUI's
    /// `ToggledEventArgs.Value`. Runs after a binding's write, if there is one.
    /// MAUI: Switch.Toggled.
    public func onToggled(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        addHandler(.toggled) {
            if let toggled = EventBuffer.current.value()?.bool {
                try await handler(toggled)
            }
        }
    }
}
