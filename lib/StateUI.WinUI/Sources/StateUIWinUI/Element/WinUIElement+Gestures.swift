// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The user's input to the view, heard by the host layer's rule (`MountedElement.hearing`, `hear`).
/// Design: docs/design/platforms/winui/input.md
extension WinUIElement {
    func configureGestures() {
        guard let view else { return }
        view.hear(element.hearing) { [weak self] heard in
            guard let self, let host else { return }
            element.hear(heard, in: host.runtime)
        }
    }
}
