// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One of a page's actions: its words, its picture, whether it can be taken, and what taking it does.
@MainActor
struct UIKitBarAction {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let perform: () -> Void

    /// Its picture: one of the application's, else none.
    private var image: UIImage? {
        icon.flatMap { $0.isEmpty ? nil : UIKitRenderer.image(named: $0) }
    }

    /// A button of the bar.
    var barItem: UIBarButtonItem {
        let item = UIBarButtonItem(primaryAction: menuAction)
        item.isEnabled = isEnabled
        return item
    }

    /// An entry of a menu.
    var menuAction: UIAction {
        let action = UIAction(title: title, image: image) { _ in perform() }
        if !isEnabled { action.attributes = .disabled }
        return action
    }
}
#endif
