// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Locale facts supplied by a native host, whenever the user's settings change.
@_spi(Host) public struct HostLocaleInfo: Equatable, Sendable {
    /// The full language tag, including its script and region where known; nil where the host has none.
    public let language: LocaleTag?

    /// The current zone by its IANA name, such as "Europe/Warsaw"; nil where the host has none.
    public let timeZone: TimeZoneName?

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    public let uses24HourClock: Bool

    /// Which day a week starts on.
    public let firstDayOfWeek: Weekday

    /// Whether the locale uses metric units.
    public let isMetric: Bool

    /// The way the language is written.
    public let writingDirection: WritingDirection

    /// The user's languages as tags, most wanted first; empty where the host says only `language`.
    public let languages: [LocaleTag]

    /// A complete locale report.
    public init(
        language: LocaleTag?,
        timeZone: TimeZoneName?,
        uses24HourClock: Bool,
        firstDayOfWeek: Weekday,
        isMetric: Bool,
        writingDirection: WritingDirection,
        languages: [LocaleTag] = []
    ) {
        self.language = language
        self.timeZone = timeZone
        self.uses24HourClock = uses24HourClock
        self.firstDayOfWeek = firstDayOfWeek
        self.isMetric = isMetric
        self.writingDirection = writingDirection
        self.languages = languages
    }
}
