// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for the drawing matrix's `sin` and `cos`.
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// A 4×4 drawing matrix acting on row vectors: a point (x, y, z, 1) is drawn
/// at (x, y, z, 1)·M divided by its fourth coordinate. `m41` and `m42` move,
/// `m34` carries perspective, and `a * b` applies `a`, then `b`.
@_spi(Host) public struct HostMatrix: Equatable, Sendable {
    /// The first row: where the across axis is drawn.
    public var m11 = 1.0, m12 = 0.0, m13 = 0.0, m14 = 0.0

    /// The second row: where the down axis is drawn.
    public var m21 = 0.0, m22 = 1.0, m23 = 0.0, m24 = 0.0

    /// The third row: where the depth axis is drawn, and its perspective.
    public var m31 = 0.0, m32 = 0.0, m33 = 1.0, m34 = 0.0

    /// The fourth row: the move.
    public var m41 = 0.0, m42 = 0.0, m43 = 0.0, m44 = 1.0

    /// The matrix that draws every point where it is.
    public static let identity = HostMatrix()

    /// `lhs` followed by `rhs`.
    public static func * (lhs: HostMatrix, rhs: HostMatrix) -> HostMatrix {
        let left = lhs.rows
        let right = rhs.rows
        var product = [[Double]](repeating: [0, 0, 0, 0], count: 4)
        for row in 0..<4 {
            for column in 0..<4 {
                var sum = 0.0
                for step in 0..<4 { sum += left[row][step] * right[step][column] }
                product[row][column] = sum
            }
        }
        return HostMatrix(rows: product)
    }

    /// Where the matrix draws a point of the view's plane.
    public func applied(to x: Double, _ y: Double) -> (x: Double, y: Double) {
        let w = x * m14 + y * m24 + m44
        return ((x * m11 + y * m21 + m41) / w, (x * m12 + y * m22 + m42) / w)
    }

    enum Axis { case x, y, z }

    static func translation(_ x: Double, _ y: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m41 = x
        matrix.m42 = y
        return matrix
    }

    static func scale(_ x: Double, _ y: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m11 = x
        matrix.m22 = y
        return matrix
    }

    static func rotation(degrees: Double, about axis: Axis) -> HostMatrix {
        guard degrees != 0 else { return .identity }
        let radians = degrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        var matrix = HostMatrix()
        switch axis {
        case .z:
            matrix.m11 = cosine; matrix.m12 = sine
            matrix.m21 = -sine; matrix.m22 = cosine
        case .x:
            matrix.m22 = cosine; matrix.m23 = sine
            matrix.m32 = -sine; matrix.m33 = cosine
        case .y:
            matrix.m11 = cosine; matrix.m13 = -sine
            matrix.m31 = sine; matrix.m33 = cosine
        }
        return matrix
    }

    static func perspective(_ distance: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m34 = -1 / distance
        return matrix
    }

    private var rows: [[Double]] {
        [
            [m11, m12, m13, m14],
            [m21, m22, m23, m24],
            [m31, m32, m33, m34],
            [m41, m42, m43, m44],
        ]
    }

    private init(rows: [[Double]]) {
        (m11, m12, m13, m14) = (rows[0][0], rows[0][1], rows[0][2], rows[0][3])
        (m21, m22, m23, m24) = (rows[1][0], rows[1][1], rows[1][2], rows[1][3])
        (m31, m32, m33, m34) = (rows[2][0], rows[2][1], rows[2][2], rows[2][3])
        (m41, m42, m43, m44) = (rows[3][0], rows[3][1], rows[3][2], rows[3][3])
    }

    private init() {}
}
