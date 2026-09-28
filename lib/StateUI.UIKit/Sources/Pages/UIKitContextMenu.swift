// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What UIKit asks as the user holds a view with a context menu: the menu, built from the tree then.
@MainActor
final class UIKitContextMenu: NSObject, UIContextMenuInteractionDelegate {
    private weak var owner: UIKitElement?

    init(owner: UIKitElement) {
        self.owner = owner
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard owner?.builtContextMenu != nil else { return nil }
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in self?.owner?.builtContextMenu })
    }
}
#endif
