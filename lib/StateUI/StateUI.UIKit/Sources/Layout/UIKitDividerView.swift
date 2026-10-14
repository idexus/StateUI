// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A divider in a stack: a hairline in the system's separator colour, one pixel thick both ways - the stack
/// stretches it across, its axis keeps it thin.
/// Design: docs/design/host/layout.md#a-divider-in-a-stack
@MainActor
final class UIKitDividerView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = .separator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitDividerView is made in code")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let pixel = 1 / max(1, traitCollection.displayScale)
        return CGSize(width: pixel, height: pixel)
    }
}
#endif
