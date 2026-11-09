// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKElement {
    /// The language the element's words are in, as the host layer resolves it: a text's words are set by it, and
    /// every element following this one's holds it again where this one's changed.
    /// Design: docs/design/platforms/gtk/controls.md#the-language-of-the-words
    func speakLanguage(changed: Set<Prop>) {
        for each in changed.contains(.language) ? element.followingLanguage : [element] {
            (each.gtk.view as? GTKTextualView)?.setLanguage(each.spokenLanguage)
        }
    }
}
