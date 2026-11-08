// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `TimePicker`'s own properties, shared by the control and its
/// `Style<TimePicker>`.
public protocol TimePickerProperties: PropertyContainer {}

extension TimePickerProperties {
    /// How much of the time is written out - hours and minutes, or seconds too.
    ///
    /// The host writes it in the user's locale, which decides between 13:00
    /// and 1:00 PM.
    ///
    ///     TimePicker($alarm).format(.medium)
    public func format(_ format: TimeFormat) -> Modified {
        setValue(TimePickerContract.format, format)
    }
}

/// A time of day, chosen from the platform's own clock.
///
///     @State private var alarm = ClockTime(hour: 7, minute: 0)
///
///     TimePicker($alarm)
///         .format(.short)
///
/// Given a binding it shows the time and writes back whatever is chosen; given
/// a plain `ClockTime` it shows that, and `.onTimeChanged` is how the choice
/// gets anywhere.
///
/// The time is a `ClockTime`: hours, minutes and seconds since midnight. The
/// picker takes `.textColor` but has no `.text`, the field showing the
/// formatted time.
public struct TimePicker: ElementView, TextColorElement, FontElement, TimePickerProperties, FocusElement, PopupElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: TimePickerContract.self)
    }

    /// A picker showing `time`. One-way: what is chosen goes nowhere without
    /// `.onTimeChanged`.
    public init(_ time: ClockTime) {
        node = Node(contract: TimePickerContract.self)
        node.write(TimePickerContract.time, time)
    }

    /// Two-way: shows the time and writes back the one that is chosen.
    public init(_ state: Binding<ClockTime>) {
        self = TimePicker().time(state)
    }

    /// The time it shows.
    func time(_ value: ClockTime) -> Modified {
        setValue(TimePickerContract.time, value)
    }

    /// The time from a state carried both ways.
    func time(_ state: Binding<ClockTime>) -> Modified {
        plain(.time, by: state, mode: .inOut)
    }

    // MARK: Events

    /// Fires when a time is chosen, with the new one. Runs after a binding's
    /// write.
    public func onTimeChanged(_ handler: @escaping @MainActor (ClockTime) throws -> Void) -> Modified {
        onEvent(TimePickerContract.timeChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onTimeChanged(policy: GatePolicy, _ handler: @escaping ValueEventHandler<ClockTime>) -> Modified {
        onEvent(TimePickerContract.timeChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onTimeChanged(gate: Gate, _ handler: @escaping ValueEventHandler<ClockTime>) -> Modified {
        onEvent(TimePickerContract.timeChanged, gate: gate, handler)
    }

}

extension TimePicker {
    /// `format` from a state, `$x`: the host writes the time each new way as it stands.
    public func format(_ state: Binding<TimeFormat>) -> Modified {
        twin(TimePickerContract.format, by: state)
    }

}
