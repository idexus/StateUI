// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a shape drawn through a list of points shares - a polygon, a polyline: which parts of an outline crossing
/// itself count as inside it, which a style may give. The points go in the initializer.
///
///     Polygon(star).fillRule(.evenOdd).fill(.gold)
public protocol PointsShape: PropertyContainer {}

extension PointsShape {
    /// Which parts of a self-crossing outline count as inside it, and so get
    /// painted by `fill`.
    ///
    /// Only the fill looks at it; the outline is drawn the same either way.
    /// The choice shows on a shape whose edges cross - a five-pointed star,
    /// where `.evenOdd` leaves the middle hollow and `.nonzero` fills it. A
    /// filled polyline is painted as though its last point were joined back
    /// to the first.
    public func fillRule(_ value: FillRule) -> Modified {
        setValue(PointsShapeContract.fillRule, value)
    }
}

extension PointsShape where Self: ModifiableElement {
    /// Its points, in order.
    func points(_ value: [Point]) -> Modified {
        setValue(PointsShapeContract.points, value)
    }

    /// `fillRule` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fillRule(_ state: Binding<FillRule>) -> Modified {
        twin(PointsShapeContract.fillRule, carrying: state)
    }
}
