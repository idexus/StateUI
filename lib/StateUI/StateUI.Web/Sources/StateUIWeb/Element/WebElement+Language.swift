// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebElement {
    /// The language the element's words are in on its view's `lang` where it holds no other from the view it stands
    /// in; every element following this one's says it again where this one's changed.
    /// Design: docs/design/platforms/web/controls.md#the-language-of-the-words
    func speakLanguage(changed: Set<Prop>) {
        for each in changed.contains(.language) ? element.followingLanguage : [element] {
            each.web.view?.setLanguage(each.languageOnItsView)
        }
    }
}
