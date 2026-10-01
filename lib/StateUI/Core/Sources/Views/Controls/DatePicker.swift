// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `DatePicker`'s own properties, shared by the control and its
/// `Style<DatePicker>`.
public protocol DatePickerProperties: PropertyContainer {}

extension DatePickerProperties {
    /// Whether the calendar is showing.
    ///
    /// Settable, so a button elsewhere on the page can open it - and the
    /// platform closes it by itself, which is what `onClosed` is for.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(DatePickerContract.isOpen, value)
    }

    /// The day the field shows. Usually given in the initializer.
    public func date(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.date, value)
    }

    /// The earliest day the calendar offers - everything before it is refused.
    public func minimumDate(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.minimumDate, value)
    }

    /// The latest day the calendar offers - everything after it is refused.
    ///
    ///     DatePicker($birthday)
    ///         .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
    ///
    /// There is no `today` to hand: a page whose limit is the current day
    /// holds that day in state.
    public func maximumDate(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.maximumDate, value)
    }

    /// How the date is written in the field, as a format string - "D" for the
    /// long form, "d" for the short one, "dd MMM yyyy" for a pattern of your
    /// own.
    ///
    /// The host formats it in the user's locale and language.
    public func format(_ value: String) -> Modified {
        setValue(DatePickerContract.format, value)
    }
}

/// A day, chosen from the platform's own calendar.
///
///     @State private var birthday = CalendarDate(year: 1990, month: 6, day: 1)
///     …
///     DatePicker($birthday)
///         .minimumDate(CalendarDate(year: 1900, month: 1, day: 1))
///         .format("D")
///
/// The date is a `CalendarDate`: a year, a month and a day. The picker takes
/// `.textColor` but has no `.text`, the field showing the formatted date.
public struct DatePicker: View, TextStyleElement, FontElement, DatePickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<DatePicker>` is written against.
    public init() {
        node = Node(contract: DatePickerContract.self)
    }

    /// A picker showing `date`. One-way: what is chosen goes nowhere without
    /// `.onDateChanged`.
    public init(_ date: CalendarDate) {
        node = Node(contract: DatePickerContract.self)
        node.write(DatePickerContract.date, date)
    }

    /// Two-way: shows the date and writes back the one that is chosen.
    public init(_ date: Binding<CalendarDate>) {
        self = DatePicker().date(date)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// The same two-way date as `DatePicker($due)`, written as a modifier.
    ///
    ///     DatePicker($due)
    ///     DatePicker().date($due)
    ///
    /// The host shows the state's day and writes back the one the user
    /// chooses, with no view rebuilt for it. A day outside
    /// `minimumDate`…`maximumDate` is shown clamped while the state keeps the
    /// day written.
    ///
    /// - Parameter value: the state shown, and written back into when a day is
    ///   chosen.
    /// - Returns: the control, wearing and reporting that day.
    public func date(_ value: Binding<CalendarDate>) -> Modified {
        value.image == nil
            ? described(.date, value, on: .dateChanged)
            : plain(.date, by: value, mode: .inOut)
    }

    // MARK: Events

    /// Fires when a date is chosen. Runs after a binding's write, if there is
    /// one.
    public func onDateChanged(_ handler: @escaping ValueEventHandler<CalendarDate>) -> Self {
        onEvent(DatePickerContract.dateChanged, handler)
    }

    /// The user has opened the calendar. Opening it with `isOpen(true)` raises
    /// nothing: the application already knows.
    public func onOpened(_ handler: @escaping EventHandler) -> Self {
        onEvent(DatePickerContract.opened, handler)
    }

    /// It has closed - by a choice, by a tap outside, or by the platform.
    public func onClosed(_ handler: @escaping EventHandler) -> Self {
        onEvent(DatePickerContract.closed, handler)
    }
}

extension DatePicker {
    /// `isOpen` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        plain(DatePickerContract.isOpen.token, by: state)
    }
}
