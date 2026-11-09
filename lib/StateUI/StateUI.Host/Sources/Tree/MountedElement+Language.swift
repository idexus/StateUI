// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The language an element's words are written in, as the library says it where a `Localization` is given and every
/// host reads it: the element's own, else the nearest above it.
/// Design: docs/design/host/runtime.md#the-language-a-branch-is-written-in
extension MountedElement {
    /// The language this element's words are written in: its own, else the nearest element's above it saying one;
    /// nil where none does, and the platform's own stands.
    public var spokenLanguage: LocaleTag? {
        ownLanguage ?? parent?.spokenLanguage
    }

    /// The language this element says itself; nil where it holds the one above it.
    public var ownLanguage: LocaleTag? {
        value(LanguageElementContract.language.token).flatMap(LocaleTag.init(propValue:))
    }

    /// The language a host whose toolkit hands a view's language to the views in it writes on this element's view:
    /// its own; else the one it holds where that comes through an element above with no view - a window, a sheet -
    /// or where the view stands apart from the views above it - a popover's, a sheet's page; nil where it holds what
    /// its view's parent holds.
    public var languageOnItsView: LocaleTag? {
        if let own = ownLanguage { return own }
        guard let spoken = spokenLanguage else { return nil }
        if type == .popover || parent?.type == .sheet { return spoken }
        var above = parent
        while let each = above, !(each.native?.presentsView ?? false) {
            if each.ownLanguage != nil { return spoken }
            above = each.parent
        }
        return nil
    }

    /// This element and every one under it holding its language - none saying one of its own, nor under one that
    /// does: what a host writing the language on each view writes again as this element's changes.
    public var followingLanguage: [MountedElement] {
        [self] + children.flatMap { $0.ownLanguage == nil ? $0.followingLanguage : [] }
    }
}
