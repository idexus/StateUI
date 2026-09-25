// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The arithmetic of a shape drawing a geometry of its own - a line, a path, a polygon, a polyline: where the
/// geometry stands in the room its layout gives it.
/// Design: docs/design/host/layout.md#a-shapes-own-geometry
@_spi(Host) public enum ShapeArithmetic {
    /// The affine transform - `a, b, c, d, tx, ty`, a point `(x, y)` going to `(a x + c y + tx, b x + d y + ty)` -
    /// that places a geometry whose bounds are `bounds` in a room `size`: scaled as `aspect` says - to fit keeping
    /// its proportions, to cover, each axis on its own, or not at all - centred, then moved by the shape's own
    /// `transform`, as a transform moves a view after its layout.
    public static func placement(
        of bounds: Rect, in size: LayoutSize, aspect: Aspect, transform: [Double]?
    ) -> [Double] {
        let across = bounds.width > 0 ? size.width / bounds.width : 0
        let down = bounds.height > 0 ? size.height / bounds.height : 0
        var scaleX = 1.0
        var scaleY = 1.0
        if bounds.width > 0 || bounds.height > 0 {
            switch aspect {
            case .stretch:
                scaleX = bounds.width > 0 ? across : 1
                scaleY = bounds.height > 0 ? down : 1
            case .center:
                break
            case .fill:
                scaleX = max(across, down)
                scaleY = scaleX
            case .fit:
                // A geometry flat along one axis fits by the other alone.
                scaleX = bounds.width > 0 && bounds.height > 0 ? min(across, down) : max(across, down)
                scaleY = scaleX
            }
        }

        let tx = size.width / 2 - (bounds.x + bounds.width / 2) * scaleX
        let ty = size.height / 2 - (bounds.y + bounds.height / 2) * scaleY
        guard let moved = transform, moved.count == 6, moved.allSatisfy(\.isFinite) else {
            return [scaleX, 0, 0, scaleY, tx, ty]
        }
        let (a, b, c, d) = (moved[0], moved[1], moved[2], moved[3])
        return [scaleX * a, scaleX * b, scaleY * c, scaleY * d, tx * a + ty * c + moved[4], tx * b + ty * d + moved[5]]
    }
}
