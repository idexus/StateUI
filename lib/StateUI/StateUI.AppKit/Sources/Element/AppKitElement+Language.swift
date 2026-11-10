// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitElement {
    /// The language the element's words are in, as the host layer resolves it: a text holds it on its words for
    /// VoiceOver, and every element following this one's holds it again where this one's changed.
    /// Design: docs/design/platforms/appkit/views.md#the-language-of-the-words
    func speakLanguage(changed: Set<Prop>) {
        for each in changed.contains(.language) ? element.followingLanguage : [element] {
            (each.appKit.view as? AppKitTextView)?.language = each.spokenLanguage?.identifier
        }
    }
}
#endif
