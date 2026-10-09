// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The user's language, region, zone and calendar habits, as the host
/// reports them. Read it with `@Environment(\.locale) private var locale`.
@MainActor
public final class LocaleInfo {
    /// The two-letter language, such as "en" or "pl".
    @State public internal(set) var language = ""

    /// The two-letter region, such as "US" or "PL", and empty where the
    /// locale has none.
    @State public internal(set) var region = ""

    /// The locale's full name, such as "en-PL".
    @State public internal(set) var name = ""

    /// The current zone's IANA identifier, such as "Europe/Warsaw". The host
    /// normalizes its native identifier; empty means it has not said.
    @State public internal(set) var timeZone = ""

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    @State public internal(set) var uses24HourClock = false

    /// Which day a week starts on here.
    @State public internal(set) var firstDayOfWeek: Weekday = .sunday

    /// Whether the locale uses metric units.
    @State public internal(set) var isMetric = true

    /// The way the language is written: left to right, or right to left - what a view left at
    /// `.inherited` lays out in.
    @State public internal(set) var layoutDirection: LayoutDirection = .leftToRight

    /// A locale as a test or a preview fakes it, for one branch with `.environment(...)`; what is not said starts as a
    /// headless host's does.
    public init(
        language: String = "", region: String = "", name: String = "", timeZone: String = "",
        uses24HourClock: Bool = false, firstDayOfWeek: Weekday = .sunday, isMetric: Bool = true,
        layoutDirection: LayoutDirection = .leftToRight
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
