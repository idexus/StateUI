// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A shape's lines and its stroke, as every host draws them.
/// Design: docs/design/host/layout.md#a-shapes-own-geometry
extension ShapeArithmetic {
    /// Points joined by lines as the flat commands a geometry is written in - move, then lines - closed where the
    /// shape is; a point that is no number is left out.
    public static func commands(through points: [Point], closed: Bool) -> [Double] {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard let first = finite.first else { return [] }
        return [0, first.x, first.y] + finite.dropFirst().flatMap { [1, $0.x, $0.y] } + (closed ? [4] : [])
    }

    /// A stroke's width, never below nothing, nothing where it is no number.
    public static func strokeWidth(_ width: Double) -> Double {
        width.isFinite ? max(0, width) : 0
    }

    /// Dashes and gaps as lengths: StateUI measures them in stroke widths.
    public static func dashLengths(_ dashes: [Double], strokeWidth: Double) -> [Double] {
        dashes.map { max(0, $0) * strokeWidth }
    }
}
