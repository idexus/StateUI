// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A time of day: hour, minute, second, and nothing else.
///
///     ClockTime(hour: 9, minute: 30)
///
/// What a `TimePicker` shows and reports, and what `ClockTime.now()` answers.
/// No date, no zone: `CalendarDate` is the other half.
///
/// Design: docs/design/types/dates-and-time.md#three-integers-each-way
public struct ClockTime: Equatable, Hashable, Comparable, Sendable, HostRepresentable {
    /// The hour, 0 to 23. Midnight is 0, and one in the afternoon is 13 - there
    /// is no am/pm here, that being a matter of `.format(…)`.
    public var hour: Int

    /// The minute, 0 to 59.
    public var minute: Int

    /// The second, 0 to 59. A `TimePicker` picks hours and minutes, so a
    /// second is only ever what the application set.
    public var second: Int

    /// The millisecond, 0 to 999, filled in by `now()` so a clock can sleep to
    /// the next whole second. A time that crosses to a host comes back with 0
    /// here.
    public var millisecond: Int

    /// A time of day. Nothing checks that the numbers make one: the host adds
    /// them up from midnight, so `ClockTime(hour: 25, minute: 99)` reaches a
    /// picker as 26 hours and 39 minutes past midnight.
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

            // Exactly three digits: "05.12" is refused rather than read as 12 ms.
            guard tail[1].count == 3, let millisecond = Int(tail[1]) else { return nil }

            self.init(hour: hour, minute: minute, second: second, millisecond: millisecond)
            return
        }

        self.init(hour: hour, minute: minute)
    }

    /// The time back from the three numbers a picker reports - hour, minute,
    /// second, each the whole part of its number, and no millisecond. Nil for
    /// anything else, so a report that does not read leaves the handler alone.
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
    /// format: a `TimePicker` writes a time for the user with `.format(…)`,
    /// against the user's locale.
    public var text: String {
        "\(pad(hour)):\(pad(minute)):\(pad(second))"
    }

    /// Hour, minute and second as three numbers, the order a picker reports
    /// them; the millisecond is not sent.
    public var propValue: PropValue {
        .numbers([Double(hour), Double(minute), Double(second)])
    }

    /// Earlier in the day than. Compares the four numbers in order, which is
    /// what makes a range a matter of `<` rather than of a clock.
    public static func < (left: ClockTime, right: ClockTime) -> Bool {
        (left.hour, left.minute, left.second, left.millisecond)
            < (right.hour, right.minute, right.second, right.millisecond)
    }

    /// Zero-padded by hand, without Foundation.
    private func pad(_ value: Int) -> String {
        value < 10 && value >= 0 ? "0\(value)" : String(value)
    }

    /// The time of day right now, by the host's clock.
    ///
    ///     let time = try await ClockTime.now()
    ///
    /// The host answers local time with milliseconds, which lets a clock sleep
    /// to the next whole second instead of drifting past it:
    ///
    ///     try await Task.sleep(for: .milliseconds(1000 - time.millisecond))
    ///
    /// Design: docs/design/types/dates-and-time.md#the-clock-is-an-act
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
    /// Hour, minute and second as three lanes; the millisecond is not carried
    /// and comes back as 0.
    public var carried: StateCarried { .lanes([Double(hour), Double(minute), Double(second)]) }

    /// A time from those three lanes. Nil for any other count, so a report
    /// that does not read leaves the state alone.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 3 else { return nil }

        self.init(hour: Int(lanes[0].rounded()), minute: Int(lanes[1].rounded()), second: Int(lanes[2].rounded()))
    }

    /// Three.
    public static var lanes: Int { 3 }
}
