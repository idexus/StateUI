// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An object given to a branch with `.environment(_:)` that says the language the branch's words are in: a
/// `Localization`, its language in use.
/// Design: docs/design/types/localization.md#the-language-a-branch-is-written-in
@MainActor
protocol LanguageSpeaking: AnyObject {
    /// The language in use.
    var spokenLanguage: LocaleTag { get }
}

extension Localization: LanguageSpeaking {
    var spokenLanguage: LocaleTag { resolvedLanguage.rawValue }
}

extension Node {
    /// Says on this element the language the nearest of `environments` speaking one speaks, read as it is described.
    mutating func sayLanguage(of environments: [(key: ObjectIdentifier, object: AnyObject)]) {
        guard let speaking = environments.last(where: { $0.object is any LanguageSpeaking })?.object
            as? any LanguageSpeaking
        else { return }
        readsWhenDescribed { node in node.write(LanguageElementContract.language, speaking.spokenLanguage) }
    }
}
