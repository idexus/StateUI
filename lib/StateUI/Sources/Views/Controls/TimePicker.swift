// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `TimePicker`'s own properties, shared by the control and its
/// `Style<TimePicker>`.
public protocol TimePickerProperties: PropertyContainer {}

extension TimePickerProperties {
    /// Whether the clock face is showing.
    ///
    /// Settable, so a button elsewhere on the page can open it - and the
    /// platform closes it by itself, which is what `onClosed` is for.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(TimePickerContract.isOpen, value)
    }

    /// The time the field is showing, on a 24-hour clock whatever `.format`
    /// draws. Usually given in the initializer.
    ///
    ///     TimePicker().time(ClockTime(hour: 7, minute: 30))
    public func time(_ value: ClockTime) -> Modified {
        setValue(TimePickerContract.time, value)
    }

    /// How the time is written - "t" for the short form, "T" for the long one,
    /// or a pattern like "HH:mm".
    ///
    /// The host formats it in the user's locale, which decides between 13:00
    /// and 1:00 PM.
    public func format(_ value: String) -> Modified {
        setValue(TimePickerContract.format, value)
    }
}

/// A time of day, chosen from the platform's own clock.
///
///     @State private var alarm = ClockTime(hour: 7, minute: 0)
///
///     TimePicker($alarm)
///         .format("t")
///
/// Given a binding it shows the time and writes back whatever is chosen; given
/// a plain `ClockTime` it shows that, and `.onTimeChanged` is how the choice
/// gets anywhere.
///
/// The time is a `ClockTime`: hours, minutes and seconds since midnight. The
/// picker takes `.textColor` but has no `.text`, the field showing the
/// formatted time.
public struct TimePicker: View, TextStyleElement, FontElement, TimePickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TimePicker>` is written against.
    public init() {
        node = Node(contract: TimePickerContract.self)
    }

    /// A picker showing `time`. One-way: what is chosen goes nowhere without
    /// `.onTimeChanged`.
    public init(_ time: ClockTime) {
        node = Node(contract: TimePickerContract.self)
        node.write(TimePickerContract.time, time)
    }

    /// Two-way: shows the time and writes back the one that is chosen.
    public init(_ time: Binding<ClockTime>) {
        self = TimePicker().time(time)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// The same two-way time as `TimePicker($alarm)`, written as a modifier.
    ///
    ///     TimePicker($alarm)
    ///     TimePicker().time($alarm)
    ///
    /// The host shows the state's time and writes back the one the user
    /// chooses, with no view rebuilt for it. A time of more than a day is shown
    /// folded into one day while the state keeps what was written.
    ///
    /// - Parameter value: the state shown, and written back into when a time
    ///   is chosen.
    /// - Returns: the control, wearing and reporting that time.
    public func time(_ value: Binding<ClockTime>) -> Modified {
        value.image == nil
            ? described(.time, value, on: .timeChanged)
            : plain(.time, by: value, mode: .inOut)
    }

    // MARK: Events

    /// Fires when a time is chosen, with the new one. Runs after a binding's
    /// write.
    public func onTimeChanged(_ handler: @escaping ValueEventHandler<ClockTime>) -> Self {
        onEvent(TimePickerContract.timeChanged, handler)
    }

    /// The user has opened the clock face. Opening it with `isOpen(true)` raises
    /// nothing: the application already knows.
    public func onOpened(_ handler: @escaping EventHandler) -> Self {
        onEvent(TimePickerContract.opened, handler)
    }

    /// It has closed - by a choice, by a tap outside, or by the platform.
    public func onClosed(_ handler: @escaping EventHandler) -> Self {
        onEvent(TimePickerContract.closed, handler)
    }
}
