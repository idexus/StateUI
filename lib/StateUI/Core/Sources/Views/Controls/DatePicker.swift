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

    /// How much of the day is written out in the field - `.long`
    /// "September 30, 2026", `.medium` "Sep 30, 2026", `.short` "9/30/26" -
    /// each in the order and the words of the user's language and region.
    public func format(_ style: DateStyle) -> Modified {
        setValue(DatePickerContract.format, style)
    }
}

/// A day, chosen from the platform's own calendar.
///
///     @State private var birthday = CalendarDate(year: 1990, month: 6, day: 1)
///     …
///     DatePicker($birthday)
///         .minimumDate(CalendarDate(year: 1900, month: 1, day: 1))
///         .format(.long)
///
/// The date is a `CalendarDate`: a year, a month and a day. The picker takes
/// `.textColor` but has no `.text`, the field showing the formatted date.
public struct DatePicker: ElementView, TextColorElement, FontElement, DatePickerProperties, FocusElement {
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
    public init(_ state: some TwoWay<CalendarDate>) {
        self = DatePicker().date(state)
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
    /// - Parameter state: the state shown, and written back into when a day is
    ///   chosen.
    /// - Returns: the control, wearing and reporting that day.
    public func date(_ state: some TwoWay<CalendarDate>) -> Modified {
        guard let whole = state.whole else {
            return described(.date, state, on: .dateChanged)
        }

        return plain(.date, by: whole, mode: .inOut)
    }

    // MARK: Events

    /// Fires when a date is chosen. Runs after a binding's write, if there is
    /// one.
    public func onDateChanged(_ handler: @escaping @MainActor (CalendarDate) throws -> Void) -> Modified {
        onEvent(DatePickerContract.dateChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDateChanged(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<CalendarDate>) -> Modified {
        onEvent(DatePickerContract.dateChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDateChanged(gate: Gate, _ handler: @escaping ValueEventHandler<CalendarDate>) -> Modified {
        onEvent(DatePickerContract.dateChanged, gate: gate, handler)
    }

    /// The user has opened the calendar. Opening it with `isOpen(true)` raises
    /// nothing: the application already knows.
    public func onOpened(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(DatePickerContract.opened, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onOpened(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(DatePickerContract.opened, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onOpened(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(DatePickerContract.opened, gate: gate, handler)
    }

    /// It has closed - by a choice, by a tap outside, or by the platform.
    public func onClosed(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(DatePickerContract.closed, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onClosed(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(DatePickerContract.closed, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClosed(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(DatePickerContract.closed, gate: gate, handler)
    }
}

extension DatePicker {
    /// `isOpen` from a state, `$x`, both ways: the host opens and closes the calendar as the state stands, and
    /// the user's opening and closing come back into it; no view is rebuilt for it.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        opening(DatePickerContract.isOpen, by: state, opened: DatePickerContract.opened, closed: DatePickerContract.closed)
    }
}
