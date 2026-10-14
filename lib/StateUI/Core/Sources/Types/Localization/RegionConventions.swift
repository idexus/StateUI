// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How one region writes numbers, days and times: separators, the order of a day's parts, the clock, the week.
/// Design: docs/design/types/localization.md#formats-in-swift
struct RegionConventions: Sendable {
    let decimal: String
    let grouping: String
    let minimumGroupingDigits: Int
    let dayFirst: Bool
    let numericDate: NumericDate
    let uses24HourClock: Bool
    let firstDayOfWeek: Weekday
    let isMetric: Bool

    /// A day in digits: its parts' order, their separator, and whether they are padded and the year whole.
    struct NumericDate: Sendable {
        let dayFirst: Bool
        let separator: String
        let padded: Bool
        let fullYear: Bool
    }

    /// The conventions of `tag`'s region, or of its language's own region where it names none; the United
    /// States', said once, for a region StateUI does not write yet.
    static func of(_ tag: LocaleTag) -> RegionConventions {
        switch tag.region ?? home[tag.language] {
        case "US": return .unitedStates
        case "GB": return .unitedKingdom
        case "PL": return .poland
        default:
            complain("StateUI writes no formats of \(tag) yet; it writes those of en-US.")
            return .unitedStates
        }
    }

    /// The region each language's formats stand for where a tag names none.
    private static let home = ["en": "US", "pl": "PL"]
}
