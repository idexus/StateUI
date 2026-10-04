// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's native drawing surface for StateUI's `ColorBox`.
@MainActor
final class AppKitColorBoxView: AppKitHitTestView {
    private(set) var backgroundColor = NSColor.clear
    private(set) var fillColor = NSColor.clear

    /// The corners' radii, clockwise from the top left.
    private(set) var radii: [Double] = [0, 0, 0, 0]

    override var isFlipped: Bool { true }

    func apply(background: NSColor?, fill: NSColor?, corners: CornerRadius?) {
        backgroundColor = background ?? .clear
        fillColor = fill ?? .clear
        radii = BoxArithmetic.clockwise(corners)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)
        context.setFillColor(fillColor.cgColor)
        context.addPath(AppKitCorners.path(in: bounds, clockwise: radii))
        context.fillPath()
    }
}

#endif
