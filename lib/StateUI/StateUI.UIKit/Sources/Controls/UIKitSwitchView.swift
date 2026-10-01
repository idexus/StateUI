// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Switch: UIKit's own. The user's turn is reported; the program's is only shown.
@MainActor
final class UIKitSwitchView: UISwitch {
    /// What the switch does when the user turned it.
    var onToggled: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onToggled?(isOn)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSwitchView is made in code")
    }
}
#endif
