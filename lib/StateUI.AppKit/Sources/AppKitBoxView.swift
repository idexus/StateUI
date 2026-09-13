// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Four independent corner radii in StateUI's top-left, top-right,
/// bottom-left, bottom-right order.
struct AppKitCornerRadii: Equatable {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    init(_ value: HostValue? = nil) {
        if let radius = value?.number {
            let radius = Self.sanitized(radius)
            topLeft = radius
            topRight = radius
            bottomLeft = radius
            bottomRight = radius
        } else if let radii = value?.numbers, radii.count >= 4 {
            topLeft = Self.sanitized(radii[0])
            topRight = Self.sanitized(radii[1])
            bottomLeft = Self.sanitized(radii[2])
            bottomRight = Self.sanitized(radii[3])
        }
    }

    init(
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomLeft: CGFloat,
        bottomRight: CGFloat
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func path(in rect: CGRect) -> CGPath {
        let radii = fitted(to: rect.size)
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radii.topRight, y: rect.minY))
        turn(
            path,
            around: CGPoint(x: rect.maxX, y: rect.minY),
            toward: CGPoint(x: rect.maxX, y: rect.minY + radii.topRight),
            radius: radii.topRight)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radii.bottomRight))
        turn(
            path,
            around: CGPoint(x: rect.maxX, y: rect.maxY),
            toward: CGPoint(x: rect.maxX - radii.bottomRight, y: rect.maxY),
            radius: radii.bottomRight)
        path.addLine(to: CGPoint(x: rect.minX + radii.bottomLeft, y: rect.maxY))
        turn(
            path,
            around: CGPoint(x: rect.minX, y: rect.maxY),
            toward: CGPoint(x: rect.minX, y: rect.maxY - radii.bottomLeft),
            radius: radii.bottomLeft)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radii.topLeft))
        turn(
            path,
            around: CGPoint(x: rect.minX, y: rect.minY),
            toward: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY),
            radius: radii.topLeft)
        path.closeSubpath()

        return path
    }

    private func fitted(to size: CGSize) -> AppKitCornerRadii {
        guard size.width > 0, size.height > 0 else { return AppKitCornerRadii() }

        func scale(_ length: CGFloat, over radii: CGFloat) -> CGFloat {
            radii > 0 ? length / radii : 1
        }

        let factor = min(
            1,
            scale(size.width, over: topLeft + topRight),
            scale(size.width, over: bottomLeft + bottomRight),
            scale(size.height, over: topLeft + bottomLeft),
            scale(size.height, over: topRight + bottomRight))

        return AppKitCornerRadii(
            topLeft: topLeft * factor,
            topRight: topRight * factor,
            bottomLeft: bottomLeft * factor,
            bottomRight: bottomRight * factor)
    }

    private func turn(
        _ path: CGMutablePath,
        around corner: CGPoint,
        toward next: CGPoint,
        radius: CGFloat
    ) {
        if radius > 0 {
            path.addArc(tangent1End: corner, tangent2End: next, radius: radius)
        } else {
            path.addLine(to: corner)
        }
    }

    private static func sanitized(_ value: Double) -> CGFloat {
        value.isFinite ? max(0, CGFloat(value)) : 0
    }
}

/// AppKit's native drawing surface for StateUI's rectangle primitive.
@MainActor
final class AppKitBoxView: NSView {
    private(set) var backgroundColor = NSColor.clear
    private(set) var fillColor = NSColor.clear
    private(set) var cornerRadii = AppKitCornerRadii()

    override var isFlipped: Bool { true }

    func apply(background: NSColor?, fill: NSColor?, cornerRadius: HostValue?) {
        backgroundColor = background ?? .clear
        fillColor = fill ?? .clear
        cornerRadii = AppKitCornerRadii(cornerRadius)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)
        context.setFillColor(fillColor.cgColor)
        context.addPath(cornerRadii.path(in: bounds))
        context.fillPath()
    }
}

#endif
