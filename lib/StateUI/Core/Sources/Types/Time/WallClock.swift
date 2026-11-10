// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The platform's clock and its zone database - read as the application's `clock`. Each answer is the host's, the
/// same on every platform, with nothing formatted or parsed.
///
///     @Environment(\.application) private var application
///
///     let time = try await application.clock.now()
///     let tokyo = try await application.clock.utcOffset(of: "Asia/Tokyo")
///
/// The zone the user is in is a fact of the locale, `locale.timeZone`.
/// Design: docs/design/types/dates-and-time.md#the-clock-is-an-act
@MainActor
public struct WallClock {
    /// The local time of day, by the host's clock - with its millisecond, which lets a clock sleep to the next whole
    /// second instead of drifting past it:
    ///
    ///     let time = try await application.clock.now()
    ///     try await Task.sleep(for: .milliseconds(1000 - time.millisecond))
    public func now() async throws -> ClockTime {
        let read = try await local()
        return ClockTime(hour: read[3], minute: read[4], second: read[5], millisecond: read[6])
    }

    /// The local day, by the host's clock.
    ///
    ///     let today = try await application.clock.today()
    public func today() async throws -> CalendarDate {
        let read = try await local()
        return CalendarDate(year: read[0], month: read[1], day: read[2])
    }

    /// How far a zone is from UTC on a day - the user's own zone where nil, the offset in effect now where no day is
    /// given. Where summer time applies, the day decides. Read the answer with `.components.seconds`; it is negative
    /// west of UTC.
    ///
    ///     let here = try await application.clock.utcOffset()
    ///     let inJanuary = try await application.clock.utcOffset(
    ///         of: "Europe/Warsaw", on: CalendarDate(year: 2026, month: 1, day: 15))
    ///
    /// Design: docs/design/types/dates-and-time.md#an-offset-on-a-day
    ///
    /// - Throws: `StateUIError` for a zone the platform does not know.
    public func utcOffset(of zone: TimeZoneName? = nil, on date: CalendarDate? = nil) async throws -> Duration {
        let minutes = try await callAct(ApplicationContract.utcOffset, zone?.identifier, date)
        return .seconds(minutes * 60)
    }

    /// The host's local date and time of day: year, month, day, hour, minute, second, millisecond.
    private func local() async throws -> [Int] {
        let numbers = try await callAct(ApplicationContract.currentTime)
        // Each the nearest whole number: one that is none - not a number, endless - is an answer unread.
        let whole = numbers.compactMap(Int.init(nearest:))
        guard numbers.count == 7, whole.count == 7 else {
            throw StateUIError.unreadableAnswer(
                act: ApplicationContract.currentTime.token.name, answered: "\(numbers)",
                declared: "seven whole numbers: a date and a time of day")
        }
        return whole
    }
}

extension ApplicationSession {
    /// The platform's clock: the local day and time of day, and a zone's distance from UTC.
    public var clock: WallClock { WallClock() }
}
