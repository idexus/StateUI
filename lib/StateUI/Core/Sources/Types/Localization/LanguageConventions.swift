// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What one language says inside a format: its plural rule, its month names as a date uses them - and the order
/// they need, where its grammar fixes one - the words of a list and of a twelve-hour clock. One file for each
/// language StateUI writes, under Languages.
/// Design: docs/design/types/localization.md#formats-in-swift
struct LanguageConventions: Sendable {
    let plural: @Sendable (Int) -> PluralCategory
    let months: [String]
    let shortMonths: [String]
    let dayFirst: Bool?
    let and: String
    let serialComma: Bool
    let morning: String
    let evening: String

    /// The conventions of `tag`'s language; English, said once, for a language StateUI does not write yet.
    static func of(_ tag: LocaleTag) -> LanguageConventions {
        switch tag.language {
        case "en": return .english
        case "pl": return .polish
        default:
            complain("StateUI writes no \(tag.language) formats yet; it writes English ones for \(tag).")
            return .english
        }
    }
}
