// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A box's outline and corners - a layout's, a button's, a colour box's, a rectangle's - as every host draws them.
/// Design: docs/design/host/layout.md#a-box
@_spi(Host) public enum BoxArithmetic {
    /// The corners' radii, clockwise from the top left - the order toolkits take them in, where StateUI names the
    /// bottom left third - each a radius of nothing where it is no number or below nothing.
    public static func clockwise(_ corners: CornerRadius?) -> [Double] {
        let radii: [Double] = switch corners {
        case .uniform(let radius): [radius, radius, radius, radius]
        case .corners(let topLeft, let topRight, let bottomLeft, let bottomRight):
            [topLeft, topRight, bottomRight, bottomLeft]
        case nil: [0, 0, 0, 0]
        }
        return radii.map { $0.isFinite ? max(0, $0) : 0 }
    }

    /// A corner's radius in a room `width` by `height`: no more than half the side it rounds.
    public static func fitted(_ radius: Double, width: Double, height: Double) -> (width: Double, height: Double) {
        (min(radius, width / 2), min(radius, height / 2))
    }

    /// The outline the tree's `value` asks for: a rectangle where it asks none, a rounded one's radius never below
    /// nothing.
    public static func outline(_ value: HostValue?) -> ContainerShape {
        guard let parts = value?.values, let kind = parts.first?.enumeration else { return .rectangle }
        switch kind {
        case 1: return .roundedRectangle(max(0, parts.count > 1 ? parts[1].number ?? 0 : 0))
        case 2: return .ellipse
        default: return .rectangle
        }
    }

    /// How wide an outline is drawn: none without a colour to draw it in, else as the tree says - one where it says
    /// nothing - never below nothing.
    public static func outlineWidth(stroke: HostValue?, width: Double?) -> Double {
        guard stroke != nil else { return 0 }
        let width = width ?? 1
        return width.isFinite ? max(0, width) : 0
    }
}
