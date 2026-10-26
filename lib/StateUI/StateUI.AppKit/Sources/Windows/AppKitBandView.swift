// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The band the title bar and toolbar cover, painted in the bars' brush - a color or a gradient over its whole
/// width - and hidden where the bars stand on the system's material.
/// Design: docs/design/platforms/appkit/runtime.md#the-bars-band
@MainActor
final class AppKitBandView: NSView {
    /// What paints the band; nothing leaves it hidden.
    var brush = AppKitBrush() {
        didSet {
            guard brush != oldValue else { return }
            isHidden = !brush.paints
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        brush.draw(in: NSBezierPath(rect: bounds), bounds: bounds)
    }
}

#endif
