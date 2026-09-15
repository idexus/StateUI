// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
/// comes BACK from a picker, so the two directions say the same thing. The
/// host reads them as a length of time SINCE MIDNIGHT rather than a point on
/// a clock.
public struct ClockTime: Equatable, Hashable, Comparable, Sendable, HostRepresentable {
    /// The hour, 0 to 23. Midnight is 0, and one in the afternoon is 13 - there
    /// is no am/pm here, that being a matter of `.format(…)`.
    public var hour: Int

    /// The minute, 0 to 59.
    public var minute: Int

    /// The second, 0 to 59. Rarely written: a TimePicker picks hours and
    /// minutes on every platform, so a second is only ever what something
    /// else set.
    public var second: Int

    /// The millisecond, 0 to 999. What `now()` fills in, so that a clock can
    /// sleep to the next whole second instead of drifting past it. The wire
    /// carries whole seconds - a TimePicker neither shows nor keeps less - so a
    /// value that travels comes back with 0 here.
    public var millisecond: Int

    /// A time of day. Nothing checks that the three make one, and neither does
    /// the host: it adds them into a length of time since midnight, so
    /// `ClockTime(hour: 25, minute: 99)` reaches the picker as 26 hours and 39
    /// minutes past midnight rather than being refused.
    public init(hour: Int, minute: Int, second: Int = 0, millisecond: Int = 0) {
        self.hour = hour
        self.minute = minute
        self.second = second
        self.millisecond = millisecond
    }

    /// Reads `09:30`, `09:30:05` and `09:30:05.123` - the fraction exactly
    /// three digits, which are milliseconds.
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

            // Exactly three digits - "05.12" would be 120ms wearing a 12, and
            // refusing it is what keeps a truncated value visible.
            guard tail[1].count == 3, let millisecond = Int(tail[1]) else { return nil }

            self.init(hour: hour, minute: minute, second: second, millisecond: millisecond)
            return
        }

        self.init(hour: hour, minute: minute)
    }

    /// The time back from the three numbers a picker reports - hour, minute,
    /// second, each the whole part of its number. Nil for anything else, a
    /// number that is not one included, so a report that will not read
    /// leaves the handler alone. A picker keeps no milliseconds, so none
    /// arrive.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 3,
              let hour = Int(exactly: numbers[0].rounded(.towardZero)),
              let minute = Int(exactly: numbers[1].rounded(.towardZero)),
              let second = Int(exactly: numbers[2].rounded(.towardZero))
        else { return nil }

        self.init(hour: hour, minute: minute, second: second)
    }

    /// The same, for a payload's value that may be missing.
    init?(_ value: PropValue?) {
        guard let value else { return nil }
        self.init(propValue: value)
    }

    /// `09:30:00` - the time as a line of text, for putting one in a label:
    /// `Label("Alarm at \(alarm.text)")`.
    ///
    /// One fixed shape, 24-hour and without the millisecond, never a display
    /// format: how a TimePicker WRITES a time for the reader is `.format(…)`,
    /// which the host does against the reader's locale. This is for text an
    /// application composes itself.
    public var text: String {
        "\(pad(hour)):\(pad(minute)):\(pad(second))"
    }

    /// Hour, minute, second - the same three a picker reports back, in the
    /// same order, so nothing is formatted going out and parsed coming in.
    /// The millisecond does not go: a TimePicker neither shows nor keeps one,
    /// which is why a value that travels comes back with 0 there.
    public var propValue: PropValue {
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

    /// The time of day right now, by the host's clock.
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
        let numbers = try await stateUICall(ApplicationContract.currentTime)

        guard numbers.count == 4 else {
            throw StateUIError(
                message: "the host's reply does not read as a time of day. Usually "
                    + "a native library and a runtime built from different versions.")
        }

        return ClockTime(
            hour: Int(numbers[0]), minute: Int(numbers[1]),
            second: Int(numbers[2]), millisecond: Int(numbers[3]))
    }
}

extension ClockTime: StateValue {
    /// Hour, minute, second - the three a picker reports back, in that order.
    /// The millisecond does not ride: a TimePicker neither shows nor keeps
    /// one, so a value the host carries comes back with 0 there, as one that
    /// crossed the wire does.
    public var carried: StateCarried { .lanes([Double(hour), Double(minute), Double(second)]) }

    /// A time from those three lanes. Nil for any other count, so a report
    /// that will not read leaves the state alone.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 3 else { return nil }

        self.init(hour: Int(lanes[0].rounded()), minute: Int(lanes[1].rounded()), second: Int(lanes[2].rounded()))
    }

    /// Three.
    public static var lanes: Int { 3 }
}
