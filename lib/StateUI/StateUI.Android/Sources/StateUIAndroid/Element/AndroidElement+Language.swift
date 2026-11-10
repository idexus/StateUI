// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidElement {
    /// The language the element's words are in, as the host layer resolves it: a view showing words sets them by it,
    /// and every element following this one's sets them again where this one's changed.
    /// Design: docs/design/platforms/android/controls.md#the-language-of-the-words
    func speakLanguage(changed: Set<Prop>) {
        for each in changed.contains(.language) ? element.followingLanguage : [element] {
            (each.android.view as? AndroidTextualView)?.setLanguage(each.spokenLanguage)
        }
    }
}
