// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitElement {
    /// The language the element's words are in, as the host layer resolves it, which VoiceOver speaks them in: each
    /// view holds it - UIKit hands a view's language to none in it - and every element following this one's holds
    /// it again where this one's changed.
    /// Design: docs/design/platforms/uikit/controls.md#the-language-of-the-words
    func speakLanguage(changed: Set<Prop>) {
        for each in changed.contains(.language) ? element.followingLanguage : [element] {
            guard let view = each.uiKit.view else { continue }
            let target = (view as? UIKitAccessibilityPresenting)?.presentedControl ?? view
            let language = each.spokenLanguage?.identifier
            if target.accessibilityLanguage != language { target.accessibilityLanguage = language }
        }
    }
}
#endif
