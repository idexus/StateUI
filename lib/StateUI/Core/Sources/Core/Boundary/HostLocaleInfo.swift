// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Locale facts supplied by a native host, whenever the user's settings change.
@_spi(Host) public struct HostLocaleInfo: Equatable, Sendable {
    /// The two-letter language, such as "en" or "pl".
    public let language: String

    /// The two-letter region, such as "US" or "PL", and empty where the locale has none.
    public let region: String

    /// The locale's full name, such as "en-PL".
    public let name: String

    /// The current zone's IANA identifier, such as "Europe/Warsaw".
    public let timeZone: String

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    public let uses24HourClock: Bool

    /// Which day a week starts on.
    public let firstDayOfWeek: Weekday

    /// Whether the locale uses metric units.
    public let isMetric: Bool

    /// The way the language is written, `.leftToRight` or `.rightToLeft`.
    public let layoutDirection: LayoutDirection

    /// A complete locale report.
    public init(
        language: String,
        region: String,
        name: String,
        timeZone: String,
        uses24HourClock: Bool,
        firstDayOfWeek: Weekday,
        isMetric: Bool,
        layoutDirection: LayoutDirection
    ) {
        self.language = language
        self.region = region
        self.name = name
        self.timeZone = timeZone
        self.uses24HourClock = uses24HourClock
        self.firstDayOfWeek = firstDayOfWeek
        self.isMetric = isMetric
        self.layoutDirection = layoutDirection
    }
}
