// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The user's language, region, zone and calendar habits, as the host
/// reports them. Resolve it with `@Environment var locale: LocaleInfo`.
public final class LocaleInfo {
    /// The two-letter language, such as "en" or "pl".
    @State public var language = ""

    /// The two-letter region, such as "US" or "PL", and empty where the
    /// locale has none.
    @State public var region = ""

    /// The locale's full name, such as "en-PL".
    @State public var name = ""

    /// The current zone's IANA identifier, such as "Europe/Warsaw". The host
    /// normalizes its native identifier; empty means it has not said.
    @State public var timeZone = ""

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    @State public var uses24HourClock = false

    /// Which day a week starts on here.
    @State public var firstDayOfWeek: Weekday = .sunday

    /// Whether the locale uses metric units.
    @State public var isMetric = true

    /// The way the language is written: left to right, or right to left - what a view left at
    /// `.inherited` lays out in.
    @State public var layoutDirection: LayoutDirection = .leftToRight

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}
