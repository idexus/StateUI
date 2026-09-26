// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An entry this host does not present yet: its name in red where it belongs, so a gap is seen rather than silent.
@MainActor
final class UIKitUnsupportedView: UILabel {
    init(_ type: NodeType) {
        super.init(frame: .zero)
        text = "UIKit: unsupported \(type.name)"
        textColor = .systemRed
        font = .preferredFont(forTextStyle: .caption1)
        numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitUnsupportedView is made in code")
    }
}
#endif
