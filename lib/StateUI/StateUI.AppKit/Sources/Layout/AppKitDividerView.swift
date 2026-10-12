// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A divider in a stack: AppKit's own separator box, which draws its line along its longer side - across a
/// vertical stack, down a horizontal one.
/// Design: docs/design/host/layout.md#a-divider-in-a-stack
final class AppKitDividerView: NSBox, AppKitWidthConstrainedMeasuring {
    init() {
        super.init(frame: .zero)
        boxType = .separator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// A line's thickness both ways: the stack stretches it across, its axis keeps it thin.
    func fittingContentSize(width: CGFloat?) -> NSSize {
        NSSize(width: 1, height: 1)
    }
}
#endif
