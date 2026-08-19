// A time of day, without Foundation.

/// A time of day: hour, minute, second, and nothing else.
///
///     ClockTime(hour: 9, minute: 30)
///
/// What a `TimePicker` shows and reports, and what `ClockTime.now()` answers.
/// No date, no zone: `CalendarDate` is the other half.
///
/// Three integers, for the reason `CalendarDate` is three integers: turning a
/// Foundation value into text needs a formatter, a formatter needs ICU, and ICU
/// is what this library cannot have.
///
/// It travels as those integers - hour, minute, second - which is also how it
/// comes BACK from a picker, so the two directions say the same thing. .NET
/// makes them the `TimeSpan` MAUI's `TimePicker.Time` is: a time SINCE
/// MIDNIGHT rather than a point on a clock, which is why 24:00 is as
/// meaningless here as it is there.
public struct ClockTime: Equatable, Hashable, Comparable, Sendable {
    /// The hour, 0 to 23. Midnight is 0, and one in the afternoon is 13 - there
    /// is no am/pm here, that being a matter of `.format(…)`.
    public var hour: Int

    /// The minute, 0 to 59.
    public var minute: Int

    /// The second, 0 to 59. Rarely written: a TimePicker picks hours and
    /// minutes on every platform, and this is what a `TimeSpan` carries when
    /// something else set it.
    public var second: Int

    /// The millisecond, 0 to 999. What `now()` fills in, so that a clock can
    /// sleep to the next whole second instead of drifting past it. The wire
    /// carries whole seconds - a TimePicker neither shows nor keeps less - so a
    /// value that travels comes back with 0 here.
    public var millisecond: Int

    /// A time of day. Nothing checks that the three make one, and neither does
    /// the host: .NET adds them into the length since midnight a `TimeSpan` is,
    /// so `ClockTime(hour: 25, minute: 99)` reaches the picker as 26:39 rather
    /// than being refused.
    public init(hour: Int, minute: Int, second: Int = 0, millisecond: Int = 0) {
        self.hour = hour
        self.minute = minute
        self.second = second
        self.millisecond = millisecond
    }

    /// Reads `09:30`, `09:30:05` and `09:30:05.123` - the fraction exactly
    /// three digits, as .NET's `fff` writes it.
    ///
    ///     guard let alarm = ClockTime(saved.alarmText) else { return }
    ///
    /// Nil for any other shape, so text that is not a time shows up at the
    /// point it is read instead of becoming a silent midnight.
    public init?(_ text: String) {
        let parts = text.split(separator: ":")

        guard parts.count == 2 || parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }

        guard parts.count == 2 else {
            let tail = parts[2].split(separator: ".")

            guard tail.count <= 2, let second = Int(tail[0]) else { return nil }

            guard tail.count == 2 else {
                self.init(hour: hour, minute: minute, second: second)
                return
            }

            // Exactly three digits, as .NET's "fff" writes them - "05.12"
            // would be 120ms wearing a 12, and refusing it is what keeps a
            // truncated value visible.
            guard tail[1].count == 3, let millisecond = Int(tail[1]) else { return nil }

            self.init(hour: hour, minute: minute, second: second, millisecond: millisecond)
            return
        }

        self.init(hour: hour, minute: minute)
    }

    /// Reads the three numbers a timeSelected payload carries - hour, minute,
    /// second. Nil for anything else, so a report that will not read leaves
    /// the handler alone. A picker keeps no milliseconds, so none arrive.
    init?(_ value: PropValue?) {
        guard let numbers = value?.numbers, numbers.count == 3 else { return nil }
        self.init(hour: Int(numbers[0]), minute: Int(numbers[1]), second: Int(numbers[2]))
    }

    /// `09:30:00` - the time as a line of text, for putting one in a label:
    /// `Label("Alarm at \(alarm.text)")`.
    ///
    /// One fixed shape, 24-hour and without the millisecond, never a display
    /// format: how a TimePicker WRITES a time for the reader is `.format(…)`,
    /// which the C# side does against the locale. This is for text an
    /// application composes itself.
    public var text: String {
        "\(pad(hour)):\(pad(minute)):\(pad(second))"
    }

    /// Hour, minute, second - the same three a picker reports back, in the
    /// same order, so nothing is formatted going out and parsed coming in.
    /// The millisecond does not go: a TimePicker neither shows nor keeps one,
    /// which is why a value that travels comes back with 0 there.
    var propValue: PropValue {
        .numbers([Double(hour), Double(minute), Double(second)])
    }

    /// Earlier in the day than. Compares the four numbers in order, which is
    /// what makes a range a matter of `<` rather than of a clock.
    public static func < (left: ClockTime, right: ClockTime) -> Bool {
        (left.hour, left.minute, left.second, left.millisecond)
            < (right.hour, right.minute, right.second, right.millisecond)
    }

    /// Zero-padded by hand: String(format:) is Foundation, and Foundation is
    /// what this type exists to avoid.
    private func pad(_ value: Int) -> String {
        value < 10 && value >= 0 ? "0\(value)" : String(value)
    }

    /// The time of day right now, by the host's clock. .NET: DateTime.Now.
    ///
    ///     let time = try await ClockTime.now()
    ///
    /// An act rather than a property, because reading a clock is the platform's
    /// business and this side deliberately has none - Foundation's calendar
    /// machinery arrives with ICU, the one dependency this library cannot take.
    /// The host answers local time with milliseconds, which is what lets a
    /// clock sleep to the NEXT second instead of drifting past it:
    ///
    ///     try await Task.sleep(for: .milliseconds(1000 - time.millisecond))
    ///
    /// The answer crosses as four numbers - hour, minute, second, millisecond -
    /// with nothing formatted or parsed on the way.
    ///
    /// - Returns: the host's local time of day.
    public static nonisolated(nonsending) func now() async throws -> ClockTime {
        let reply = try await stateUICall(.dateTimeNow)

        guard let numbers = reply.value()?.numbers, numbers.count == 4 else {
            throw StateUIError(
                message: "the host's reply does not read as a time of day. Usually "
                    + "a native library and a runtime built from different versions.")
        }

        return ClockTime(
            hour: Int(numbers[0]), minute: Int(numbers[1]),
            second: Int(numbers[2]), millisecond: Int(numbers[3]))
    }
}
