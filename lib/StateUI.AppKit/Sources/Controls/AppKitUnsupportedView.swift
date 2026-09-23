// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The view for a control this host does not present yet: the control's
/// name in red, where the control belongs, so the gap is visible.
@MainActor
final class AppKitUnsupportedView: AppKitHitTestView {
    private let label: NSTextField

    init(_ type: NodeType) {
        label = NSTextField(labelWithString: "AppKit: unsupported \(type.name)")
        super.init(frame: .zero)
        label.textColor = .systemRed
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitUnsupportedView is created in code")
    }

    override var intrinsicContentSize: NSSize { label.intrinsicContentSize }

    override func layout() {
        super.layout()
        label.frame = bounds
    }
}
#endif
