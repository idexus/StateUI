// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The outline the tree gives a field - its color and width - and the shape its ground and outline follow, drawn on a
/// layer of the field's in place of its bezel.
/// Design: docs/design/platforms/appkit/registrations.md#a-fields-outline
@MainActor
final class AppKitFieldOutline {
    private(set) var stroke: NSColor?
    private(set) var width: CGFloat = 0
    private(set) var shape: ContainerShape?

    /// Whether the tree outlines or shapes the field, its bezel stepping aside.
    var isDrawn: Bool { stroke != nil || shape != nil }

    /// Takes what the tree says of the outline, by the host layer's reading of it (`BoxArithmetic`).
    func set(stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        self.stroke = HostBrush(stroke).firstColor.flatMap(nsColor)
        width = CGFloat(BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth))
        self.shape = shape.map(BoxArithmetic.outline)
    }

    /// Draws it on `layer` at `size` - a capsule's ends follow it - its corners `ownRadius` where the tree says no
    /// shape.
    func draw(on layer: CALayer?, size: NSSize, ownRadius: CGFloat) {
        layer?.borderWidth = width
        layer?.borderColor = stroke?.cgColor
        layer?.cornerRadius = shape.map {
            CGFloat(BoxArithmetic.cornerRadius(of: $0, width: Double(size.width), height: Double(size.height)))
        } ?? ownRadius
    }
}
#endif
