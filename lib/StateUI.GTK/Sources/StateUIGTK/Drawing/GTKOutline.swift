// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// An outline over a size as GSK's rounded rectangle: a rectangle, one with rounded corners, or an ellipse.
extension ContainerShape {
    /// The outline over `bounds`, each corner fitted to the room (`BoxArithmetic.fitted`).
    func rounded(_ bounds: graphene_rect_t) -> GskRoundedRect {
        let (width, height) = (Double(bounds.size.width), Double(bounds.size.height))
        let fitted: (width: Double, height: Double) = switch self {
        case .rectangle: (0, 0)
        case .roundedRectangle(let radius): BoxArithmetic.fitted(radius, width: width, height: height)
        case .ellipse: (width / 2, height / 2)
        }
        let corner = graphene_size_t(width: Float(fitted.width), height: Float(fitted.height))
        return GTKOutline.rounded(bounds, corners: [corner, corner, corner, corner])
    }
}

/// GSK's rounded rectangle.
enum GTKOutline {
    /// `bounds` with its corners - top left, top right, bottom right, bottom left - rounded each by its own size.
    static func rounded(_ bounds: graphene_rect_t, corners: [graphene_size_t]) -> GskRoundedRect {
        var rounded = GskRoundedRect()
        var bounds = bounds
        var (topLeft, topRight, bottomRight, bottomLeft) = (corners[0], corners[1], corners[2], corners[3])
        gsk_rounded_rect_init(&rounded, &bounds, &topLeft, &topRight, &bottomRight, &bottomLeft)
        return rounded
    }
}

