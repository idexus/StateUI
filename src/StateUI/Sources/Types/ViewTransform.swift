// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for `sin`, `cos` and `atan2` - NOT
// Foundation, which stays out of the library: the C runtime is linked
// everywhere already, and there is no run loop anywhere in it. The libraries
// agree with each other to more places than any screen can show.
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// How a view is moved, turned and sized - ONE transform, about the view's own
/// centre, happening in the ORDER it is written. This library's own.
///
/// It is the ONE transform in the library: a view wears it through
/// `.transform(_:)`, applied about its centre after the layout has placed it,
/// and a `Path`'s geometry takes the same value through `.renderTransform(_:)`
/// - where the whole matrix draws, skew included, because a geometry is
/// redrawn rather than carried by the five view properties.
///
///     Card(item).transform(.rotate(45).scale(2).translate(100, 100))
///
/// Read it left to right: the card is turned 45 degrees, then made twice the
/// size, then moved a hundred along and a hundred down - each part happening
/// to what the parts before it made, which is why the order MATTERS.
/// `.rotate(45).translate(100, 0)` moves the turned card a hundred to the
/// right, while `.translate(100, 0).rotate(45)` swings that move round with
/// the turn. The parts compose as a matrix, and the arithmetic is done HERE,
/// on this side - the trigonometry the platform C library's, which every
/// platform agrees on to more places than a screen can show - so a transform
/// is the same picture on iOS, Android, Mac Catalyst, Windows and Linux.
///
/// What it comes to on the view is MAUI's own five, about the view's centre:
/// `TranslationX`, `TranslationY`, `Rotation`, `ScaleX` and `ScaleY` - each an
/// ordinary property, so a CHANGED transform travels like any other value,
/// every part of it at once. `Scale` is left alone, so a `.scale(_:)` written
/// on the view multiplies on top of this.
///
/// THE ONE LIMIT IS A SHEAR. Those five can say any move, any turn and any
/// sizing of the turned view - but not a sizing along one axis of a view
/// turned EARLIER (`.rotate(45).scaleX(2)`), which slants a rectangle into a
/// parallelogram that no platform here has a property to draw. Such a chain is
/// drawn as the nearest thing the five can say: the turn, the move and both
/// sizes are kept, and the slant alone is left out.
public struct ViewTransform: Equatable, Sendable {
    /// The view as it was drawn: not moved, not turned, its own size.
    public static let identity = ViewTransform()

    // The transform is the matrix of what has been written so far -
    // x' = a·x + c·y + tx, y' = b·x + d·y + ty - and each part multiplies
    // onto it. MAUI's five are read back OUT of it (below), which is where a
    // shear falls away.

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

    // A transform is written as a chain of its parts, so each part is offered
    // as a STARTING POINT as well - `.rotate(14).scale(0.9)` rather than
    // `.identity.rotate(14).scale(0.9)`, which says the same and reads worse.

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

    /// Moves the view, in device units - along and down - AFTER everything
    /// written before it: the move is not turned or sized by what follows, and
    /// is by what came first.
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
    /// its centre - AFTER everything written before it, which a turn swings
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
    /// - AFTER everything written before it, which a sizing grows or shrinks
    /// with it, moves included.
    ///
    /// - Parameter factor: 1 is as drawn, a half is half as big.
    /// - Returns: the transform, sized.
    public func scale(_ factor: Double) -> ViewTransform {
        sized(factor, factor)
    }

    /// Sizes the view across alone. On a view turned EARLIER this is the one
    /// chain the five properties cannot carry whole - the slant it makes is
    /// left out, and the type's own note says why.
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

    /// Turns the view away about its VERTICAL axis, in degrees - the side
    /// swinging back, which is what puts a gallery's cards on a wheel.
    ///
    ///     .transform(.turn(-40).scale(0.86))
    ///
    /// Drawn FLAT, with no camera anywhere: a rectangle turned by an angle is a
    /// rectangle `cos(angle)` as wide, and written that way it is the same
    /// picture on every platform. `.rotationY` is the other reading - a real
    /// three-dimensional turn - and every platform projects that one through a
    /// camera of its own.
    ///
    /// - Parameter degrees: how far to turn away. The sign says which side goes
    ///   back; both look the same drawn flat, and it is kept so the arithmetic
    ///   either side of a middle can be written as one line.
    /// - Returns: the transform, turned away.
    public func turn(_ degrees: Double) -> ViewTransform {
        sized(ViewTransform.flat(degrees), 1)
    }

    /// Turns the view away about its HORIZONTAL axis, in degrees - the top
    /// swinging back. Drawn flat, exactly as `turn(_:)` is.
    ///
    /// - Parameter degrees: how far to tip away.
    /// - Returns: the transform, tipped away.
    public func tilt(_ degrees: Double) -> ViewTransform {
        sized(1, ViewTransform.flat(degrees))
    }

    /// Leans the view over, in degrees - each vertical line leaning `x`
    /// degrees over, each horizontal line `y` degrees down - AFTER everything
    /// written before it. MAUI: SkewTransform, on a geometry.
    ///
    /// A GEOMETRY draws a lean whole (`.renderTransform(_:)`). The five VIEW
    /// properties cannot - the lean is exactly the slant the type's own note
    /// says is left out - so on a view this part changes nothing.
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

    // MAUI's five, read back out of the matrix. The turn is the angle the
    // ACROSS axis ended up at, the width is that axis's length, and the height
    // is how far the down axis reaches from it - which keeps a mirror (a
    // negative height) and drops a shear, there being no property to give one
    // to.

    /// How far the view is carried along.
    var x: Double { tx }

    /// How far the view is carried down.
    var y: Double { ty }

    // A chain that never turned is read back WITHOUT the general arithmetic:
    // the square root and the divide would hand a written 0.9 back with a last
    // bit of noise on it, and a value that is exactly what was written is what
    // the wire should carry.

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

    /// What a turn of this many degrees looks like drawn flat, never less than
    /// nothing: past a right angle a view is showing its back, which is not a
    /// picture this can make, so the turn stops there.
    ///
    /// - Parameter degrees: the angle.
    /// - Returns: how much of its width is left.
    private static func flat(_ degrees: Double) -> Double {
        max(0, cos(min(abs(degrees), 90) * Double.pi / 180))
    }
}
