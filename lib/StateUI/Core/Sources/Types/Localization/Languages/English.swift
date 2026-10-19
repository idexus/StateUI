// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// English, the regions whose formats StateUI writes for it, and StateUI's own words in it.
// Design: docs/design/types/localization.md#formats-in-swift

extension LanguageConventions {
    /// One for 1, other for every other count; a day in either order, as the region writes it.
    static let english = LanguageConventions(
        plural: { $0 == 1 ? .one : .other },
        months: [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ],
        shortMonths: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        dayFirst: nil,
        and: "and",
        serialComma: true,
        morning: "AM",
        evening: "PM")
}

extension LibraryWords {
    static let english = LibraryWords(
        ok: "OK", cancel: "Cancel",
        chrome: ChromeWords(back: "Back", sidebar: "Sidebar", close: "Close", more: "More", mainMenu: "Main Menu"))
}

extension RegionConventions {
    static let unitedStates = RegionConventions(
        decimal: ".", grouping: ",", minimumGroupingDigits: 1, dayFirst: false,
        numericDate: NumericDate(dayFirst: false, separator: "/", padded: false, fullYear: false),
        uses24HourClock: false, firstDayOfWeek: .sunday, isMetric: false)

    static let unitedKingdom = RegionConventions(
        decimal: ".", grouping: ",", minimumGroupingDigits: 1, dayFirst: true,
        numericDate: NumericDate(dayFirst: true, separator: "/", padded: true, fullYear: true),
        uses24HourClock: true, firstDayOfWeek: .monday, isMetric: true)
}
