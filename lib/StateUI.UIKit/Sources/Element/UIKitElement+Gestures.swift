// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The user's input to the view, heard by the host layer's rule (`MountedElement.hearing`, `hear`).
/// Design: docs/design/platforms/uikit/input.md
extension UIKitElement {
    func configureGestures() {
        guard let view else { return }
        let hearing = element.hearing
        guard hearing != (listening?.hearing ?? []) else { return }
        let listening = listening ?? UIKitListening(view: view)
        listening.onHeard = { [weak self] heard in
            guard let self, let host else { return }
            element.hear(heard, in: host.runtime)
        }
        listening.listen(for: hearing)
        self.listening = hearing.isEmpty ? nil : listening
    }
}
#endif
