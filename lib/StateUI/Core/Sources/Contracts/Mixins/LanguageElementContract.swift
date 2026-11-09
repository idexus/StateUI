// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The language a branch of the interface is written in: the one a screen reader speaks its words in, and whose rules
/// set them - where they break, how they hyphenate. The library says it where a `Localization` is given - the
/// language it speaks - and everything under that element holds it, as the nearest wins.
public enum LanguageElementContract: Tier {
    /// The tier's name.
    public static let name = "LanguageElement"

    /// The language the element's words, and those of everything under it, are written in; none where the platform's
    /// own stands.
    public static let language = ElementProperty<Self, LocaleTag>("language", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [language]
}
