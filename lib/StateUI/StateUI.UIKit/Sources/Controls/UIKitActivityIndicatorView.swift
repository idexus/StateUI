// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ActivityIndicator: UIKit's own, turning while the work runs and standing still, shown, while it does not.
@MainActor
final class UIKitActivityIndicatorView: UIActivityIndicatorView {
    init() {
        super.init(style: .medium)
        hidesWhenStopped = false
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("UIKitActivityIndicatorView is made in code")
    }

    /// Turns while `running`.
    func setRunning(_ running: Bool) {
        if running { startAnimating() } else { stopAnimating() }
    }
}
#endif
