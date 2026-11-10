// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the doc comments' examples lean on, declared as an application declares it - its window kinds, its keys, its
/// own types, the sessions a page reads - so the compiler reaches the library past them.
/// Design: docs/design/README.md#the-examples-of-a-doc-comment
enum DocCommentPrelude {
    static let text = """
        extension WindowKind where Value == Void {
            static let about = WindowKind("notes.about")
            static let editor = WindowKind("notes.editor")
            static let fonts = WindowKind("notes.fonts")
            static let inspector = WindowKind("notes.inspector")
            static let preferences = WindowKind("notes.preferences")
        }

        extension WindowKind where Value == Int {
            static let document = WindowKind("notes.document")
        }

        extension PersistentKey where Value == Int {
            static let lastGroup = PersistentKey("notes.lastGroup")
        }

        extension SceneKey where Value == Int {
            static let section = SceneKey("notes.section")
        }

        extension StyleKey where Target == Text {
            static let headline = StyleKey("Headline")
        }

        enum Span: CaseIterable {
            case day, week, month
        }

        enum Language: LocaleTag, CaseIterable {
            case english = "en"
            case polish = "pl"
        }

        enum Catalog: LocalizationCatalog {
            static let defaultLanguage = Language.english
        }

        @MainActor let application = ApplicationSession()
        @MainActor let localization = Localization(Catalog.self)

        """
}
