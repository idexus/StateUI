// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the host knows about time zones: which zone the user is in, and how
/// far a zone is from UTC on a given day - the same answer on every platform.
///
///     let zone = try await TimeZoneInfo.local()
///     let tokyo = try await TimeZoneInfo.utcOffset(of: "Asia/Tokyo")
///
/// Design: docs/design/types/dates-and-time.md#time-zones-come-from-the-host
public enum TimeZoneInfo {
    /// The IANA identifier of the host's local zone - `Europe/Warsaw` -
    /// converted from the platform's own zone name where it uses one.
    ///
    ///     let zone = try await TimeZoneInfo.local()
    ///
    /// On Android, an application that wants Foundation's own zones calls
    /// `setenv("TZ", zone, 1)` with this before its first `TimeZone` use.
    ///
    /// - Returns: the IANA identifier of the host's local time zone.
    public static nonisolated(nonsending) func local() async throws -> String {
        try await stateUICall(ApplicationContract.currentTimeZone)
    }

    /// How far a zone is from UTC on a given day.
    ///
    ///     let here = try await TimeZoneInfo.utcOffset()
    ///     let tokyo = try await TimeZoneInfo.utcOffset(of: "Asia/Tokyo")
    ///     let inJanuary = try await TimeZoneInfo.utcOffset(
    ///         on: CalendarDate(year: 2026, month: 1, day: 15))
    ///
    /// Read the answer with `.components.seconds`. Where summer time applies,
    /// the day decides: the offset is that day's, or today's when no day is
    /// given.
    ///
    /// Design: docs/design/types/dates-and-time.md#an-offset-on-a-day
    ///
    /// - Parameters:
    ///   - zone: an IANA identifier, or nil for the host's own zone.
    ///   - date: the day to ask about, or nil for today.
    /// - Returns: the zone's distance from UTC, negative west of it.
    public static nonisolated(nonsending) func utcOffset(
        of zone: String? = nil,
        on date: CalendarDate? = nil
    ) async throws -> Duration {
        let minutes = try await stateUICall(ApplicationContract.utcOffset, zone, date)

        return .seconds(minutes * 60)
    }
}
