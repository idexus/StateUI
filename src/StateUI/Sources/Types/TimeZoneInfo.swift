// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's time zones, without Foundation.

/// What the host knows about time zones. .NET: TimeZoneInfo.
///
/// Two questions - which zone the reader is in, and how far a zone is from UTC
/// on a given day - and the host answers both the same way on every platform
/// while Foundation does not. Measured: Apple answers everything
/// itself; Android detects no zone at all until `TZ` names one (its tz database
/// is packed in a format Foundation does not read, so `TimeZone.current` comes
/// up GMT, while a NAMED zone resolves perfectly out of ICU's own copy); and
/// Windows links only `FoundationEssentials`, which carries no zone database -
/// there, a named zone is nil and nothing sets it. The gallery's Foundation
/// probe sample shows each platform's answers side by side.
///
/// So a zone reached through here is the same answer everywhere, the way
/// `ClockTime.now()` is the same clock everywhere.
public enum TimeZoneInfo {
    /// The IANA identifier of the host's local zone - `Europe/Warsaw`. .NET:
    /// TimeZoneInfo.Local, converted from a Windows zone name where the
    /// platform uses its own.
    ///
    ///     let zone = try await TimeZoneInfo.local()
    ///
    /// On Android this is also what unlocks Foundation's own zones, for an
    /// application that wants them: `setenv("TZ", zone, 1)` before the first
    /// `TimeZone` use, the variable being read ahead of any detection.
    ///
    /// - Returns: the IANA identifier of the host's local time zone.
    public static nonisolated(nonsending) func local() async throws -> String {
        guard let zone = try await stateUICall(.localTimeZone).value()?.string else {
            throw StateUIError(
                message: "the host's reply does not read as a zone name. Usually "
                    + "a native library and a runtime built from different versions.")
        }

        return zone
    }

    /// How far a zone is from UTC on a given day. .NET:
    /// TimeZoneInfo.GetUtcOffset.
    ///
    ///     let here = try await TimeZoneInfo.getUtcOffset()
    ///     let tokyo = try await TimeZoneInfo.getUtcOffset(of: "Asia/Tokyo")
    ///     let inJanuary = try await TimeZoneInfo.getUtcOffset(
    ///         on: CalendarDate(year: 2026, month: 1, day: 15))
    ///
    /// A `Duration` rather than a `ClockTime`, because an offset can be
    /// negative and a ClockTime is a time of DAY - and because Duration is
    /// Swift's own, needing no Foundation. Read it with `.components.seconds`.
    ///
    /// The day decides the answer wherever summer time does: ask for one and
    /// the offset is that day's, ask for none and it is today's. The host reads
    /// the day at NOON, which is the one hour no zone has ever moved.
    ///
    /// - Parameters:
    ///   - zone: an IANA identifier, or empty for the host's own zone.
    ///   - date: the day to ask about, or nil for today.
    /// - Returns: the zone's distance from UTC, negative west of it.
    public static nonisolated(nonsending) func getUtcOffset(
        of zone: String = "",
        on date: CalendarDate? = nil
    ) async throws -> Duration {
        // The zone is a string because an IANA identifier IS text - `Europe/
        // Warsaw` is not a member of anything this side knows. The day is its
        // three numbers, and `.nothing` for "today": an argument list has no
        // such thing as a field left out, so absence has to be said out loud.
        let reply = try await stateUICall(
            .getUtcOffset,
            [.string(zone), date?.propValue ?? .nothing])

        guard let minutes = reply.value()?.int else {
            throw StateUIError(
                message: "the host's reply does not read as a number of minutes. Usually "
                    + "a native library and a runtime built from different versions.")
        }

        return .seconds(minutes * 60)
    }
}
