// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One part of an application's resources - a screen's, a feature's, a document's - in every language of its
/// catalog: words, messages, typefaces, pictures, any value that differs by language.
///
///     struct FilesResources: LocalizedResources {
///         typealias Catalog = AppCatalog
///
///         let title: String
///         let fileCount: Message<Int>
///
///         static func resources(for language: AppLanguage) -> FilesResources {
///             switch language {
///             case .english: .english
///             case .polish: .polish
///             }
///         }
///     }
///
/// Each language is a `static let` in a file of its own. A view reads the part in the language of the nearest
/// `Localization` with `@Environment private var res: FilesResources`.
///
/// Design: docs/design/types/localization.md#a-catalog-and-its-parts
@MainActor
public protocol LocalizedResources {
    /// The catalog whose languages this part speaks.
    associatedtype Catalog: LocalizationCatalog

    /// The whole part in one language.
    static func resources(for language: Catalog.Language) -> Self
}
