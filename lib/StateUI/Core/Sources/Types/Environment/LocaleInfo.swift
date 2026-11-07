// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The user's language, region, zone and calendar habits, as the host
/// reports them. Read it with `@Environment(\.locale) private var locale`.
@MainActor
public final class LocaleInfo {
    /// The user's language as a tag - the language, and its script and region where they are said: `"en-PL"`, its
    /// `language` "en" and its `region` "PL". Nil until the host has said.
    public internal(set) var language: LocaleTag? {
        get { _language }
        set { _language = newValue }
    }

    @State private var _language: LocaleTag?

    /// The user's languages, most wanted first, each with its script and region where the host says them:
    /// `["pl-PL", "en-GB"]`. Empty where the host gives only `language`.
    public internal(set) var languages: [LocaleTag] {
        get { _languages }
        set { _languages = newValue }
    }

    @State private var _languages: [LocaleTag] = []

    /// The zone the user is in, such as "Europe/Warsaw" - the host normalizes its native name to the IANA one; nil
    /// until the host has said. `application.clock` answers its distance from UTC.
    public internal(set) var timeZone: TimeZoneName? {
        get { _timeZone }
        set { _timeZone = newValue }
    }

    @State private var _timeZone: TimeZoneName?

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    public internal(set) var uses24HourClock: Bool {
        get { _uses24HourClock }
        set { _uses24HourClock = newValue }
    }

    @State private var _uses24HourClock = false

    /// Which day a week starts on here.
    public internal(set) var firstDayOfWeek: Weekday {
        get { _firstDayOfWeek }
        set { _firstDayOfWeek = newValue }
    }

    @State private var _firstDayOfWeek: Weekday = .sunday

    /// Whether the locale uses metric units.
    public internal(set) var isMetric: Bool {
        get { _isMetric }
        set { _isMetric = newValue }
    }

    @State private var _isMetric = true

    /// The way the language is written: left to right, or right to left - what a view left at
    /// `LayoutDirection.inherited` lays out in at the root.
    public internal(set) var writingDirection: WritingDirection {
        get { _writingDirection }
        set { _writingDirection = newValue }
    }

    @State private var _writingDirection: WritingDirection = .leftToRight

    /// A locale as a test or a preview fakes it, for one branch with `.environment(...)`; what is not said starts as a
    /// headless host's does.
    public init(
        language: LocaleTag? = nil, timeZone: TimeZoneName? = nil,
        uses24HourClock: Bool = false, firstDayOfWeek: Weekday = .sunday, isMetric: Bool = true,
        writingDirection: WritingDirection = .leftToRight, languages: [LocaleTag] = []
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
