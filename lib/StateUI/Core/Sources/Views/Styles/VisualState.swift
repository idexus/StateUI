// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One state a control can be in, for the control type `Target`: after the
/// dot are the states that control enters, so `Style<Switch>().visualState(.on)`
/// compiles and `Style<Button>().visualState(.on)` does not.
public struct VisualState<Target>: Equatable, Sendable {
    /// The state's name.
    public let name: String

    /// A state by its name - only the states offered below, each of which
    /// StateUI enters.
    init(_ name: String) {
        self.name = name
    }
}

/// The states every view has.
extension VisualState where Target: VisualElement {
    /// The ordinary state - what a control is in when none of its other states
    /// holds, written or not.
    public static var normal: Self { Self("Normal") }

    /// While `isEnabled` is false.
    public static var disabled: Self { Self("Disabled") }

    /// While the control has the keyboard focus, or what stands in it does.
    public static var focused: Self { Self("Focused") }

    /// While a mouse or pen is over the control. Never on a touch-only device.
    public static var pointerOver: Self { Self("PointerOver") }
}

/// A Button is held down.
extension VisualState where Target == Button {
    /// While the button is held down - by a finger, a pointer or a key.
    public static var pressed: Self { Self("Pressed") }
}

/// A Switch says which way it is.
extension VisualState where Target == Switch {
    /// While `isOn` is true.
    public static var on: Self { Self("On") }

    /// While `isOn` is false.
    public static var off: Self { Self("Off") }
}

/// A CheckBox has one state of its own - the Switch's word for it.
extension VisualState where Target == CheckBox {
    /// While `isOn` is true. A CheckBox that is not on is in `.normal`.
    public static var on: Self { Self("On") }
}

/// A RadioButton has two, and neither is spelled the CheckBox's way.
extension VisualState where Target == RadioButton {
    /// While `isOn` is true.
    public static var checked: Self { Self("Checked") }

    /// While `isOn` is false.
    public static var unchecked: Self { Self("Unchecked") }
}
