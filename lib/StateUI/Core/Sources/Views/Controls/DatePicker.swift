// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `DatePicker`'s own properties, shared by the control and its
/// `Style<DatePicker>`.
public protocol DatePickerProperties: PropertyContainer {}

extension DatePickerProperties {
    /// The earliest day the calendar offers - everything before it is refused.
    public func minimum(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.minimum, value)
    }

    /// The latest day the calendar offers - everything after it is refused.
    ///
    ///     DatePicker($birthday)
    ///         .maximum(CalendarDate(year: 2026, month: 12, day: 31))
    ///
    /// There is no `today` to hand: a page whose limit is the current day
    /// holds that day in state.
    public func maximum(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.maximum, value)
    }

    /// How much of the day is written out in the field - `.long`
    /// "September 30, 2026", `.medium` "Sep 30, 2026", `.short` "9/30/26" -
    /// each in the order and the words of the user's language and region.
    public func format(_ format: DateFormat) -> Modified {
        setValue(DatePickerContract.format, format)
    }
}

/// A day, chosen from the platform's own calendar.
///
///     @State private var birthday = CalendarDate(year: 1990, month: 6, day: 1)
///     …
///     DatePicker($birthday)
///         .minimum(CalendarDate(year: 1900, month: 1, day: 1))
///         .format(.long)
///
/// The date is a `CalendarDate`: a year, a month and a day. The picker takes
/// `.textColor` but has no `.text`, the field showing the formatted date.
public struct DatePicker: ElementView, TextColorElement, FontElement, DatePickerProperties, FocusElement, PopupElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: DatePickerContract.self)
    }

    /// A picker showing `date`. One-way: what is chosen goes nowhere without
    /// `.onDateChanged`.
    public init(_ date: CalendarDate) {
        node = Node(contract: DatePickerContract.self)
        node.write(DatePickerContract.date, date)
    }

    /// Two-way: shows the date and writes back the one that is chosen.
    public init(_ state: Binding<CalendarDate>) {
        self = DatePicker().date(state)
    }

    /// The day it shows.
    func date(_ value: CalendarDate) -> Modified {
        setValue(DatePickerContract.date, value)
    }

    /// The day from a state carried both ways.
    func date(_ state: Binding<CalendarDate>) -> Modified {
        plain(.date, by: state, mode: .inOut)
    }

    // MARK: Events

    /// Fires when a date is chosen. Runs after a binding's write, if there is
    /// one.
    public func onDateChanged(_ handler: @escaping @MainActor (CalendarDate) throws -> Void) -> Modified {
        onEvent(DatePickerContract.dateChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDateChanged(policy: GatePolicy, _ handler: @escaping ValueEventHandler<CalendarDate>) -> Modified {
        onEvent(DatePickerContract.dateChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDateChanged(gate: Gate, _ handler: @escaping ValueEventHandler<CalendarDate>) -> Modified {
        onEvent(DatePickerContract.dateChanged, gate: gate, handler)
    }

}

extension DatePicker {
    /// `minimum` from a state, `$x`: the host sets each new earliest day as it stands.
    public func minimum(_ state: Binding<CalendarDate>) -> Modified {
        twin(DatePickerContract.minimum, by: state)
    }

    /// `maximum` from a state, `$x`: the host sets each new latest day as it stands.
    public func maximum(_ state: Binding<CalendarDate>) -> Modified {
        twin(DatePickerContract.maximum, by: state)
    }

    /// `format` from a state, `$x`: the host writes the day each new way as it stands.
    public func format(_ state: Binding<DateFormat>) -> Modified {
        twin(DatePickerContract.format, by: state)
    }

}
