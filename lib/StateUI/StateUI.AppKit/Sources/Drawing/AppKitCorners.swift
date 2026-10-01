// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A box with four corners of their own - a rectangle's, a colour box's - drawn by the host layer's rule
/// (`BoxArithmetic`): each corner no more than half the side it rounds, an ellipse's quarter where the room is
/// narrower one way.
/// Design: docs/design/host/layout.md#a-box
enum AppKitCorners {
    /// The outline of `rect`, drawn from the top, its corners' radii `clockwise` from the top left.
    static func path(in rect: CGRect, clockwise radii: [Double]) -> CGPath {
        let fitted = (0..<4).map { index in
            BoxArithmetic.fitted(index < radii.count ? radii[index] : 0, width: rect.width, height: rect.height)
        }
        let (topLeft, topRight, bottomRight, bottomLeft) = (fitted[0], fitted[1], fitted[2], fitted[3])
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight.width, y: rect.minY))
        corner(
            path, to: CGPoint(x: rect.maxX, y: rect.minY + topRight.height),
            through: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height))
        corner(
            path, to: CGPoint(x: rect.maxX - bottomRight.width, y: rect.maxY),
            through: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft.width, y: rect.maxY))
        corner(
            path, to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height),
            through: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft.height))
        corner(
            path, to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY),
            through: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    /// A quarter of an ellipse from where the path stands to `end`, bending around the box's corner `through`.
    private static func corner(_ path: CGMutablePath, to end: CGPoint, through corner: CGPoint) {
        let start = path.currentPoint
        guard start != corner, end != corner else { return path.addLine(to: end) }
        // A cubic's control points a quarter of an ellipse sets: this share of the way to the corner.
        let share: CGFloat = 0.552_284_75
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + (corner.x - start.x) * share, y: start.y + (corner.y - start.y) * share),
            control2: CGPoint(x: end.x + (corner.x - end.x) * share, y: end.y + (corner.y - end.y) * share))
    }
}

#endif
