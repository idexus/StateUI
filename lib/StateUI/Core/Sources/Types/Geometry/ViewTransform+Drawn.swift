// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A transform as a view draws it.
extension ViewTransform {
    /// The transform that undoes this one; nil for one that flattens a view to nothing.
    var inverted: ViewTransform? {
        let determinant = a * d - b * c
        guard abs(determinant) > 1e-12 else { return nil }

        var inverse = ViewTransform()
        inverse.a = d / determinant
        inverse.b = -b / determinant
        inverse.c = -c / determinant
        inverse.d = a / determinant
        inverse.tx = -(inverse.a * tx + inverse.c * ty)
        inverse.ty = -(inverse.b * tx + inverse.d * ty)
        return inverse
    }

    /// The transform as a view draws it: its five numbers - the move, the turn and the sizes - its slant dropped.
    /// Design: docs/design/types/transforms.md#the-shear-limit
    var drawn: ViewTransform {
        ViewTransform(x: x, y: y, rotation: rotation, width: width, height: height)
    }
}
