// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ProgressBar: UIKit's own bar, as far along as the work went, in the tint the tree gives.
@MainActor
final class UIKitProgressBarView: UIProgressView {
    init() {
        super.init(frame: .zero)
        progressViewStyle = .default
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitProgressBarView is made in code")
    }
}
#endif
