// MAUI: DatePicker.

/// DatePicker's own properties - the half a `Style<DatePicker>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol DatePickerProperties: PropertyContainer {}

extension DatePickerProperties {
    /// Whether the calendar is showing. MAUI: DatePicker.IsOpen.
    ///
    /// Settable, so a button elsewhere on the page can open it - and the
    /// platform closes it by itself, which is what `onClosed` is for.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(.isOpen, .bool(value))
    }

    /// The day the field shows. MAUI: DatePicker.Date.
    ///
    /// Usually given in the initializer instead; this is the way to set it in a
    /// style, or on a picker built elsewhere.
    public func date(_ value: CalendarDate) -> Modified {
        setValue(.date, value.propValue)
    }

    /// The earliest day the calendar offers - everything before it is refused.
    /// MAUI: DatePicker.MinimumDate.
    public func minimumDate(_ value: CalendarDate) -> Modified {
        setValue(.minimumDate, value.propValue)
    }

    /// The latest day the calendar offers - everything after it is refused.
    /// MAUI: DatePicker.MaximumDate.
    ///
    ///     DatePicker($birthday)
    ///         .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
    ///
    /// There is no `today` to hand: `ClockTime.now()` asks the host for the
    /// TIME of day and there is no date beside it, so a page whose limit is the
    /// current day holds that day in state.
    public func maximumDate(_ value: CalendarDate) -> Modified {
        setValue(.maximumDate, value.propValue)
    }

    /// How the date is written in the field, as a .NET format string - "D" for
    /// the long form, "d" for the short one, "dd MMM yyyy" for a pattern of
    /// your own. MAUI: DatePicker.Format.
    ///
    /// The formatting happens on the C# side, where the calendar and the
    /// reader's locale are - which is also why the month names come out in the
    /// reader's language without anything being asked for.
    public func format(_ value: String) -> Modified {
        setValue(.format, .string(value))
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
/// The date is a `CalendarDate` - a year, a month and a day - rather than
/// Foundation's `Date`, which this library does not import; see that type for
/// what it promises on each platform.
///
/// `TextStyleElement` rather than `TextElement`: MAUI's DatePicker colours its
/// text and spaces its letters but has no Text property, the field showing the
/// formatted date. So `.textColor` works here and `.text` does not exist.
public struct DatePicker: View, TextStyleElement, FontElement, DatePickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<DatePicker>` is written against.
    public init() {
        node = Node(type: .datePicker)
    }

    /// A picker showing `date`. One-way: what is chosen goes nowhere without
    /// `.onDateSelected`.
    public init(_ date: CalendarDate) {
        node = Node(type: .datePicker, props: [.date: date.propValue])
    }

    /// Two-way: shows the date and writes back the one that is chosen.
    public init(_ date: Binding<CalendarDate>) {
        node = Node(type: .datePicker, props: [.date: date.wrappedValue.propValue])
        node.addHandler(.dateSelected) {
            if let selected = CalendarDate(EventBuffer.current.value()) {
                date.wrappedValue = selected
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when a date is chosen. Runs after a binding's write, if there is
    /// one. MAUI: DatePicker.DateSelected.
    public func onDateSelected(_ handler: @escaping ValueEventHandler<CalendarDate>) -> Self {
        addHandler(.dateSelected) {
            if let date = CalendarDate(EventBuffer.current.value()) {
                try await handler(date)
            }
        }
    }

    /// The calendar has opened. MAUI: DatePicker.Opened.
    ///
    /// THE TRAP: it answers the READER opening it and not `isOpen(true)`
    /// - measured on Mac Catalyst, where the tree opening it really does open
    /// the platform's own and raises nothing. An application that opens it
    /// from a button of its own already knows, so what this is for is the
    /// other direction.
    public func onOpened(_ handler: @escaping EventHandler) -> Self {
        addHandler(.opened, handler)
    }

    /// It has closed - by a choice, by a tap outside, or by the platform.
    /// MAUI: DatePicker.Closed.
    public func onClosed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.closed, handler)
    }
}
