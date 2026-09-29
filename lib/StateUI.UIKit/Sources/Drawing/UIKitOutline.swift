// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A box's outline as a path - the host layer's reading of it (`BoxArithmetic`).
/// Design: docs/design/host/layout.md#a-box
extension ContainerShape {
    /// The outline within `rect`, a corner no more than half the side it rounds.
    func path(in rect: CGRect) -> CGPath {
        switch self {
        case .rectangle:
            return CGPath(rect: rect, transform: nil)
        case .roundedRectangle(let radius):
            let fitted = BoxArithmetic.fitted(radius, width: rect.width, height: rect.height)
            return .rounded(rect, corners: Array(repeating: CGSize(width: fitted.width, height: fitted.height), count: 4))
        case .ellipse:
            return CGPath(ellipseIn: rect, transform: nil)
        }
    }
}

extension CGPath {
    /// `rect` with each corner rounded by its own radii - top left, top right, bottom right, bottom left, as
    /// `BoxArithmetic.clockwise` gives them - each a quarter of an ellipse.
    static func rounded(_ rect: CGRect, corners: [CGSize]) -> CGPath {
        guard corners.count == 4, corners.contains(where: { $0.width > 0 && $0.height > 0 }) else {
            return CGPath(rect: rect, transform: nil)
        }
        // How far along a quarter's tangents its control points stand, for a cubic that follows the ellipse.
        let reach = 0.5523
        let (topLeft, topRight, bottomRight, bottomLeft) = (corners[0], corners[1], corners[2], corners[3])
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight.width, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topRight.height),
            control1: CGPoint(x: rect.maxX - topRight.width * (1 - reach), y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + topRight.height * (1 - reach)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height))
        path.addCurve(
            to: CGPoint(x: rect.maxX - bottomRight.width, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height * (1 - reach)),
            control2: CGPoint(x: rect.maxX - bottomRight.width * (1 - reach), y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft.width, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height),
            control1: CGPoint(x: rect.minX + bottomLeft.width * (1 - reach), y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height * (1 - reach)))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft.height))
        path.addCurve(
            to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + topLeft.height * (1 - reach)),
            control2: CGPoint(x: rect.minX + topLeft.width * (1 - reach), y: rect.minY))
        path.closeSubpath()
        return path
    }
}
#endif
