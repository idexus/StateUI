// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ProgressBar: UIKit's own bar, as far along as the work went, in the tint the tree gives - standing across the
/// middle of the room its layout gives it, as UIKit's bar keeps its own height.
@MainActor
final class UIKitProgressBarView: UIView {
    let bar = UIProgressView(progressViewStyle: .default)

    init() {
        super.init(frame: .zero)
        addSubview(bar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitProgressBarView is made in code")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        bar.sizeThatFits(size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bar.sizeThatFits(bounds.size).height
        bar.frame = CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
    }
}
#endif
