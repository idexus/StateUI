// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for `sin`, `cos` and `atan2`, not Foundation.
// Design: docs/design/types/transforms.md#the-arithmetic-is-in-the-core
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// How a view is moved, turned and sized: one transform about the view's
/// centre, its parts applied in the order written.
///
///     Card(item).transform(.rotate(45).scale(2).translate(100, 100))
///
/// Read it left to right: the card is turned 45 degrees, then doubled in size,
/// then moved 100 along and 100 down, each part applying to what the parts
/// before it made. `.rotate(45).translate(100, 0)` moves the turned card to
/// the right, while `.translate(100, 0).rotate(45)` swings the move round with
/// the turn.
///
/// A view wears it through `.transform(_:)` as five properties that animate
/// like any other - `translationX`, `translationY`, `rotation`, `scaleX` and
/// `scaleY` - and its own `.scale(_:)` multiplies on top. A `Path` takes it
/// through `.renderTransform(_:)`, where the whole matrix draws. A view cannot
/// show a shear: after a turn, a sizing along one axis
/// (`.rotate(45).scaleX(2)`) keeps the turn, the move and both sizes, and
/// drops the slant.
///
/// Design: docs/design/types/transforms.md#the-shear-limit
public struct ViewTransform: Equatable, Sendable {
    /// The view as it was drawn: not moved, not turned, its own size.
    public static let identity = ViewTransform()

    // The matrix of the parts so far: x' = a·x + c·y + tx, y' = b·x + d·y + ty.

    /// What the across axis becomes: how much of it stays across.
    var a = 1.0

    /// What the across axis becomes: how much of it turns down.
    var b = 0.0

    /// What the down axis becomes: how much of it turns across.
    var c = 0.0

    /// What the down axis becomes: how much of it stays down.
    var d = 1.0

    /// How far the centre is carried along.
    var tx = 0.0

    /// How far the centre is carried down.
    var ty = 0.0

    /// A view as it was drawn. Every part written after it happens in order.
    public init() {}

    // Each part is also a starting point: `.rotate(14)`, not `.identity.rotate(14)`.

    /// A view moved, in device units - along and down.
    ///
    /// - Parameters:
    ///   - x: how far along.
    ///   - y: how far down.
    /// - Returns: a transform that moves the view.
    public static func translate(_ x: Double, _ y: Double) -> ViewTransform {
        identity.translate(x, y)
    }

    /// A view turned in the plane of the screen, in degrees, clockwise about
    /// its centre.
    ///
    /// - Parameter degrees: how far to turn.
    /// - Returns: a transform that turns the view.
    public static func rotate(_ degrees: Double) -> ViewTransform {
        identity.rotate(degrees)
    }

    /// A view sized about its centre, as a fraction of what it was drawn at.
    ///
    /// - Parameter factor: 1 is as drawn, a half is half as big.
    /// - Returns: a transform that sizes the view.
    public static func scale(_ factor: Double) -> ViewTransform {
        identity.scale(factor)
    }

    /// A view sized across alone.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: a transform that sizes the view across.
    public static func scaleX(_ factor: Double) -> ViewTransform {
        identity.scaleX(factor)
    }

    /// A view sized down alone.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: a transform that sizes the view down.
    public static func scaleY(_ factor: Double) -> ViewTransform {
        identity.scaleY(factor)
    }

    /// A view turned away about its vertical axis, in degrees, drawn flat.
    ///
    /// - Parameter degrees: how far to turn away.
    /// - Returns: a transform that turns the view away.
    public static func turn(_ degrees: Double) -> ViewTransform {
        identity.turn(degrees)
    }

    /// A view tipped away about its horizontal axis, in degrees, drawn flat.
    ///
    /// - Parameter degrees: how far to tip away.
    /// - Returns: a transform that tips the view away.
    public static func tilt(_ degrees: Double) -> ViewTransform {
        identity.tilt(degrees)
    }

    /// A view leaned over - degrees along, then degrees down.
    ///
    /// - Parameters:
    ///   - x: the lean along, in degrees.
    ///   - y: the lean down, in degrees.
    /// - Returns: a transform that leans the view.
    public static func skew(_ x: Double, _ y: Double) -> ViewTransform {
        identity.skew(x, y)
    }

    /// Moves the view, in device units - along and down - after everything
    /// written before it: the parts before it do not turn or size the move,
    /// and the parts after it do.
    ///
    /// - Parameters:
    ///   - x: how far along.
    ///   - y: how far down.
    /// - Returns: the transform, moved.
    public func translate(_ x: Double, _ y: Double) -> ViewTransform {
        var copy = self
        copy.tx += x
        copy.ty += y
        return copy
    }

    /// Turns the view in the plane of the screen, in degrees, clockwise about
    /// its centre - after everything written before it, which the turn swings
    /// round with it.
    ///
    /// - Parameter degrees: how far to turn.
    /// - Returns: the transform, turned.
    public func rotate(_ degrees: Double) -> ViewTransform {
        let turned = degrees * Double.pi / 180
        let run = cos(turned)
        let rise = sin(turned)

        var copy = self
        copy.a = run * a - rise * b
        copy.b = rise * a + run * b
        copy.c = run * c - rise * d
        copy.d = rise * c + run * d
        copy.tx = run * tx - rise * ty
        copy.ty = rise * tx + run * ty
        return copy
    }

    /// Sizes the view about its centre, as a fraction of what it was drawn at
    /// - after everything written before it, which the sizing grows or
    /// shrinks with it, moves included.
    ///
    /// - Parameter factor: 1 is as drawn, a half is half as big.
    /// - Returns: the transform, sized.
    public func scale(_ factor: Double) -> ViewTransform {
        sized(factor, factor)
    }

    /// Sizes the view across alone. After a turn this makes a slant, which a
    /// view leaves out; see the type's note.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: the transform, sized across.
    public func scaleX(_ factor: Double) -> ViewTransform {
        sized(factor, 1)
    }

    /// Sizes the view down alone. The note on `scaleX(_:)` holds here too.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: the transform, sized down.
    public func scaleY(_ factor: Double) -> ViewTransform {
        sized(1, factor)
    }

    /// Turns the view away about its vertical axis, in degrees - the side
    /// swinging back, which is what puts a gallery's cards on a wheel.
    ///
    ///     .transform(.turn(-40).scale(0.86))
    ///
    /// Drawn flat, as a rectangle `cos(angle)` as wide, so it is the same
    /// picture on every platform; `.rotationY` is a three-dimensional turn each
    /// platform projects its own way.
    ///
    /// Design: docs/design/types/transforms.md#turned-away-drawn-flat
    ///
    /// - Parameter degrees: how far to turn away; either sign draws the same.
    /// - Returns: the transform, turned away.
    public func turn(_ degrees: Double) -> ViewTransform {
        sized(ViewTransform.flat(degrees), 1)
    }

    /// Turns the view away about its horizontal axis, in degrees - the top
    /// swinging back. Drawn flat, as `turn(_:)` is.
    ///
    /// - Parameter degrees: how far to tip away.
    /// - Returns: the transform, tipped away.
    public func tilt(_ degrees: Double) -> ViewTransform {
        sized(1, ViewTransform.flat(degrees))
    }

    /// Leans the view over, in degrees - each vertical line leaning `x`
    /// degrees over, each horizontal line `y` degrees down - after everything
    /// written before it.
    ///
    /// A `Path` draws the lean through `.renderTransform(_:)`; on a view it
    /// changes nothing, since a view cannot show a slant.
    ///
    /// - Parameters:
    ///   - x: the lean along, in degrees.
    ///   - y: the lean down, in degrees.
    /// - Returns: the transform, leaned over.
    public func skew(_ x: Double, _ y: Double) -> ViewTransform {
        let along = tan(x * Double.pi / 180)
        let down = tan(y * Double.pi / 180)

        var copy = self
        copy.a = a + along * b
        copy.b = down * a + b
        copy.c = c + along * d
        copy.d = down * c + d
        copy.tx = tx + along * ty
        copy.ty = down * tx + ty
        return copy
    }

    /// A sizing, done to everything written before it.
    private func sized(_ across: Double, _ down: Double) -> ViewTransform {
        var copy = self
        copy.a = across * a
        copy.b = down * b
        copy.c = across * c
        copy.d = down * d
        copy.tx = across * tx
        copy.ty = down * ty
        return copy
    }

    // The five view properties, read back out of the matrix: a mirror survives
    // as a negative height, a shear does not.
    // Design: docs/design/types/transforms.md#reading-the-five-properties-back

    /// The transform the five read-outs describe, as a host carries them back:
    /// an across axis of length `width` turned by `rotation`, and a down axis
    /// of length `height` square to it.
    init(x: Double, y: Double, rotation: Double, width: Double, height: Double) {
        let turned = rotation * Double.pi / 180
        let run = cos(turned)
        let rise = sin(turned)

        self.init()

        a = width * run
        b = width * rise
        c = -height * rise
        d = height * run
        tx = x
        ty = y
    }

    /// How far the view is carried along.
    var x: Double { tx }

    /// How far the view is carried down.
    var y: Double { ty }

    // A chain that never turned is read back exactly, without the square root.

    /// The turn in the plane of the screen, in degrees.
    var rotation: Double {
        if b == 0 && c == 0 { return a < 0 ? 180 : 0 }
        return atan2(b, a) * 180 / Double.pi
    }

    /// How wide, as a fraction of the view's own width.
    var width: Double {
        if b == 0 && c == 0 { return a < 0 ? -a : a }
        return (a * a + b * b).squareRoot()
    }

    /// How tall, as a fraction of the view's own height.
    var height: Double {
        if b == 0 && c == 0 { return a < 0 ? -d : d }

        let across = (a * a + b * b).squareRoot()
        if across == 0 { return (c * c + d * d).squareRoot() }
        return (a * d - b * c) / across
    }

    /// How much of its width a view keeps turned this far, drawn flat; the turn
    /// stops at a right angle, past which a view would show its back.
    private static func flat(_ degrees: Double) -> Double {
        max(0, cos(min(abs(degrees), 90) * Double.pi / 180))
    }
}

extension ViewTransform: HostRepresentable {
    /// The matrix's six numbers - a, b, c, d, then the translation - each a
    /// value of its own.
    public var propValue: PropValue {
        .values([.number(a), .number(b), .number(c), .number(d), .number(tx), .number(ty)])
    }

    /// A transform back from its six numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let values = propValue.values, values.count == 6 else { return nil }

        let numbers = values.compactMap(\.number)
        guard numbers.count == 6 else { return nil }

        self.init()
        a = numbers[0]
        b = numbers[1]
        c = numbers[2]
        d = numbers[3]
        tx = numbers[4]
        ty = numbers[5]
    }
}
