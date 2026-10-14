// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The languages an application speaks, and the one it falls back to - nothing else, so it never grows.
///
///     enum AppLanguage: String, CaseIterable, Sendable {
///         case english = "en"
///         case polish = "pl"
///     }
///
///     enum AppCatalog: LocalizationCatalog {
///         static let defaultLanguage = AppLanguage.english
///     }
///
/// Each language's raw value is its tag (`LocaleTag`). The resources live in parts of their own
/// (`LocalizedResources`), beside the views that show them.
///
/// Design: docs/design/types/localization.md#a-catalog-and-its-parts
public protocol LocalizationCatalog {
    /// The application's languages: an enum whose raw values are language tags.
    associatedtype Language: RawRepresentable<String>, CaseIterable, Hashable, Sendable

    /// The language that stands in where none of the user's matches.
    static var defaultLanguage: Language { get }
}
