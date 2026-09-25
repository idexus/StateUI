// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// An outline: a rectangle, one with rounded corners, or an ellipse - as GSK's rounded rectangle over a size.
enum GTKOutline: Equatable {
    case rectangle

    /// Corners rounded by a radius in logical pixels.
    case rounded(Double)

    case ellipse

    /// A layout's shape as it crosses: its kind, then a rectangle's radius.
    init(container value: HostValue?) {
        guard let parts = value?.values, let kind = parts.first?.enumeration else {
            self = .rectangle
            return
        }

        switch kind {
        case 1: self = .rounded(max(0, parts.value(1)?.number ?? 0))
        case 2: self = .ellipse
        default: self = .rectangle
        }
    }

    /// The outline over `bounds`, each corner's radius no more than half the side it rounds.
    func rounded(_ bounds: graphene_rect_t) -> GskRoundedRect {
        let (width, height) = (bounds.size.width, bounds.size.height)
        let corner: graphene_size_t = switch self {
        case .rectangle: graphene_size_t(width: 0, height: 0)
        case .rounded(let radius):
            graphene_size_t(width: min(Float(radius), width / 2), height: min(Float(radius), height / 2))
        case .ellipse: graphene_size_t(width: width / 2, height: height / 2)
        }
        return GTKOutline.rounded(bounds, corners: [corner, corner, corner, corner])
    }

    /// `bounds` with its corners - top left, top right, bottom right, bottom left - rounded each by its own size.
    static func rounded(_ bounds: graphene_rect_t, corners: [graphene_size_t]) -> GskRoundedRect {
        var rounded = GskRoundedRect()
        var bounds = bounds
        var (topLeft, topRight, bottomRight, bottomLeft) = (corners[0], corners[1], corners[2], corners[3])
        gsk_rounded_rect_init(&rounded, &bounds, &topLeft, &topRight, &bottomRight, &bottomLeft)
        return rounded
    }
}
