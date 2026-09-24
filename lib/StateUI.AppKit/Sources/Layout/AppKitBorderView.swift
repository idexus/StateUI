// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A border that clips its background, its outline and what it holds to the
/// requested shape.
@MainActor
final class AppKitBorderView: AppKitSingleChildView {
    let decoration = AppKitDecoration()

    override func layout() {
        super.layout()
        decoration.clip(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        decoration.draw(in: bounds)
    }
}

#endif
