// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// An outline over a size as GSK's rounded rectangle: a rectangle, one with rounded corners, a capsule, or an
/// ellipse.
extension ContainerShape {
    /// The outline over `bounds`, its corners rounded as far as the room holds them (`BoxArithmetic.cornerRadius`).
    func rounded(_ bounds: graphene_rect_t) -> GskRoundedRect {
        let (width, height) = (Double(bounds.size.width), Double(bounds.size.height))
        let radius = BoxArithmetic.cornerRadius(of: self, width: width, height: height)
        let corner = self == .ellipse
            ? graphene_size_t(width: Float(width / 2), height: Float(height / 2))
            : graphene_size_t(width: Float(radius), height: Float(radius))
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

