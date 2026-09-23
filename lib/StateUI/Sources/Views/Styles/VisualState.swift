// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One state a control can be in, for the control type `Target`: after the
/// dot are the states that control enters, so `Style<Switch>().visualState(.on)`
/// compiles and `Style<Button>().visualState(.on)` does not. Names are spelled
/// as the host matches them: "PointerOver", not "pointerOver".
public struct VisualState<Target>: Equatable, Sendable {
    /// The name a state is matched on, spelled exactly.
    public let name: String

    /// A state by its name, for one this type does not name yet. Spell it as
    /// the host matches it: `VisualState("PointerOver")`, not "pointerOver".
    public init(_ name: String) {
        self.name = name
    }
}

/// The states every view has, driven for every visual element.
extension VisualState where Target: VisualElement {
    /// The ordinary state - nothing pressed, focused or disabled. What a control
    /// returns to.
    public static var normal: Self { Self("Normal") }

    /// While `isEnabled` is false.
    public static var disabled: Self { Self("Disabled") }

    /// While the control has the keyboard focus.
    public static var focused: Self { Self("Focused") }

    /// While the control does not have the keyboard focus. A control enters it
    /// right after Normal, so a group declaring both rests here.
    public static var unfocused: Self { Self("Unfocused") }

    /// While a mouse or pen is over the control. Never on a touch-only device.
    public static var pointerOver: Self { Self("PointerOver") }

    /// While the control is the chosen one - entered by whatever does the
    /// choosing, such as a `PositionIndicator`'s dots drawn from views.
    public static var selected: Self { Self("Selected") }

}

/// A Button is held down.
extension VisualState where Target == Button {
    /// While the button is held down. The host raises it from the platform, so
    /// this is a real press rather than a gesture recognized on this side.
    public static var pressed: Self { Self("Pressed") }
}

/// A Switch says which way it is.
extension VisualState where Target == Switch {
    /// While `isOn` is true.
    public static var on: Self { Self("On") }

    /// While `isOn` is false.
    public static var off: Self { Self("Off") }
}

/// A CheckBox has ONE state of its own - the Switch's word for it.
extension VisualState where Target == CheckBox {
    /// While `isOn` is true. There is no off state beside it: a CheckBox that
    /// is not on is in `.normal`.
    public static var on: Self { Self("On") }
}

/// A RadioButton has two, and neither is spelled the CheckBox's way.
extension VisualState where Target == RadioButton {
    /// While `isOn` is true.
    public static var checked: Self { Self("Checked") }

    /// While `isOn` is false - where a RadioButton rests, since it enters
    /// Checked or Unchecked before Normal.
    public static var unchecked: Self { Self("Unchecked") }
}
