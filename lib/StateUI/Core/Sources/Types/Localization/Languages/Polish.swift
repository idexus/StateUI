// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Polish, and Poland's formats.
// Design: docs/design/types/localization.md#formats-in-swift

extension LanguageConventions {
    /// The months in the genitive, as a date says them, so the day always comes first: "30 września 2026".
    static let polish = LanguageConventions(
        plural: polishPlural,
        months: [
            "stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca",
            "lipca", "sierpnia", "września", "października", "listopada", "grudnia",
        ],
        shortMonths: ["sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru"],
        dayFirst: true,
        and: "i",
        serialComma: false,
        morning: "AM",
        evening: "PM")

    /// One for 1; few for 2-4, 22-24, 32-34 and on; many for every other whole number.
    private static func polishPlural(_ count: Int) -> PluralCategory {
        let whole = count.magnitude
        if whole == 1 { return .one }
        if (2...4).contains(whole % 10), !(12...14).contains(whole % 100) { return .few }
        return .many
    }
}

extension RegionConventions {
    /// A hard space groups from five digits up: 1234, 12 345.
    static let poland = RegionConventions(
        decimal: ",", grouping: "\u{A0}", minimumGroupingDigits: 2, dayFirst: true,
        numericDate: NumericDate(dayFirst: true, separator: ".", padded: true, fullYear: true),
        uses24HourClock: true, firstDayOfWeek: .monday, isMetric: true)
}
