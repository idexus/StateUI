// MAUI: TimePicker.

/// TimePicker's own properties - the half a `Style<TimePicker>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol TimePickerProperties: PropertyContainer {}

extension TimePickerProperties {
    /// The time the field is showing, on a 24-hour clock whatever `.format`
    /// draws. MAUI: TimePicker.Time.
    ///
    ///     TimePicker().time(ClockTime(hour: 7, minute: 30))
    ///
    /// `TimePicker(alarm)` and `TimePicker($alarm)` both say this from their
    /// argument, so a modifier written beside one wins - and a binding goes on
    /// being written back to, which is how the two can then disagree.
    public func time(_ value: ClockTime) -> Modified {
        setValue(.time, value.propValue)
    }

    /// How the time is written, in .NET's format strings - "t" for the short
    /// form, "T" for the long one, or a pattern like "HH:mm".
    /// MAUI: TimePicker.Format.
    ///
    /// Formatting happens on the C# side, where a locale is available and costs
    /// nothing - which is also what decides whether the reader sees 13:00 or
    /// 1:00 PM.
    public func format(_ value: String) -> Modified {
        setValue(.format, .string(value))
    }
}

/// A time of day, chosen from the platform's own clock. MAUI: TimePicker.
///
///     @State private var alarm = ClockTime(hour: 7, minute: 0)
///
///     TimePicker($alarm)
///         .format("t")
///
/// Given a binding it shows the time and writes back whatever is chosen; given
/// a plain `ClockTime` it shows that, and `.onTimeSelected` is how the choice
/// gets anywhere.
///
/// The time is a `ClockTime` rather than a Foundation value - see that type for
/// why. MAUI's `TimePicker.Time` is a `TimeSpan`, a length SINCE MIDNIGHT, which
/// is what three integers describe exactly.
///
/// `TextStyleElement` rather than `TextElement`: MAUI's TimePicker colours its
/// text and spaces its letters, and has no Text property - the field shows the
/// formatted time.
public struct TimePicker: View, TextStyleElement, FontElement, TimePickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TimePicker>` is written against.
    public init() {
        node = Node(type: .timePicker)
    }

    /// A picker showing `time`. One-way: what is chosen goes nowhere without
    /// `.onTimeSelected`.
    public init(_ time: ClockTime) {
        node = Node(type: .timePicker, props: [.time: time.propValue])
    }

    /// Two-way: shows the time and writes back the one that is chosen.
    public init(_ time: Binding<ClockTime>) {
        node = Node(type: .timePicker, props: [.time: time.wrappedValue.propValue])
        node.addHandler(.timeSelected) {
            if let selected = ClockTime(EventBuffer.current.value()) {
                time.wrappedValue = selected
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when a time is chosen, with the new one - MAUI's
    /// `TimeChangedEventArgs.NewTime`. Runs after a binding's write, if there is
    /// one. MAUI: TimePicker.TimeSelected.
    public func onTimeSelected(_ handler: @escaping ValueEventHandler<ClockTime>) -> Self {
        addHandler(.timeSelected) {
            if let time = ClockTime(EventBuffer.current.value()) {
                try await handler(time)
            }
        }
    }
}
