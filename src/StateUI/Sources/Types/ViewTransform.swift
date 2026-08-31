// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a view is moved, turned and sized - one transform, about the view's own
/// centre. This library's own.
///
/// It is `ViewTransform` rather than `Transform` because that name is MAUI's,
/// and belongs to the transform of a SHAPE'S GEOMETRY - which can skew, and
/// which the stroke follows. This one is the VIEW's, applied after the layout
/// has placed it.
///
///     Card(item).transform { $0.rotate(14).scale(0.9).translate(100, 200) }
///
/// THE POINT OF IT IS THAT IT MEANS THE SAME PICTURE EVERYWHERE. A move, a turn
/// in the plane of the screen and a change of size are the same arithmetic
/// wherever they are drawn, so a transform written here is the same picture on
/// iOS, Android, Mac Catalyst, Windows and Linux - which the properties it
/// stands for are not all able to promise on their own. `.rotationX` and
/// `.rotationY` are MAUI's and stay MAUI's, projected through a camera each
/// platform chooses for itself; `turn` and `tilt` below are the same idea drawn
/// FLAT, and a card turned that way looks alike on every screen.
///
/// **THE ORDER IN WHICH IT IS WRITTEN DOES NOT MATTER**, and that is the whole
/// design rather than an accident. Each part ACCUMULATES into its own number -
/// moves add up, turns in the plane add up, sizes multiply - so
/// `$0.rotate(14).scale(0.9)` and `$0.scale(0.9).rotate(14)` are the same
/// transform, and there is no chain a screen cannot draw. A transform that
/// composed matrices instead could be asked for a SHEAR, which no platform here
/// has a property for; this one cannot be.
///
/// What it comes to on the view is MAUI's own five: `TranslationX`,
/// `TranslationY`, `Rotation`, `ScaleX` and `ScaleY`, all about the anchor -
/// which is the middle of the view unless the view says otherwise. `Scale` is
/// left alone, so a `.scale(_:)` written on the view multiplies on top of this.
public struct ViewTransform: Equatable, Sendable {
    /// The view as it was drawn: not moved, not turned, its own size.
    public static let identity = ViewTransform()

    /// How far along, in device units.
    var x = 0.0

    /// How far down, in device units.
    var y = 0.0

    /// The turn in the plane of the screen, in degrees.
    var rotation = 0.0

    /// How wide, as a fraction of the view's own width.
    var width = 1.0

    /// How tall, as a fraction of the view's own height.
    var height = 1.0

    /// A view as it was drawn. Every part is then added to it.
    public init() {}

    /// Moves the view, in device units - along and down, and it adds to
    /// whatever moving has already been asked for.
    ///
    /// - Parameters:
    ///   - x: how far along.
    ///   - y: how far down.
    /// - Returns: the transform, moved.
    public func translate(_ x: Double, _ y: Double) -> ViewTransform {
        var copy = self
        copy.x += x
        copy.y += y
        return copy
    }

    /// Turns the view in the plane of the screen, in degrees, clockwise about
    /// its centre - added to whatever turning has already been asked for.
    ///
    /// - Parameter degrees: how far to turn.
    /// - Returns: the transform, turned.
    public func rotate(_ degrees: Double) -> ViewTransform {
        var copy = self
        copy.rotation += degrees
        return copy
    }

    /// Sizes the view about its centre, as a fraction of what it was drawn at -
    /// multiplied into whatever sizing has already been asked for.
    ///
    /// - Parameter factor: 1 is as drawn, a half is half as big.
    /// - Returns: the transform, sized.
    public func scale(_ factor: Double) -> ViewTransform {
        var copy = self
        copy.width *= factor
        copy.height *= factor
        return copy
    }

    /// Sizes the view across alone.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: the transform, sized across.
    public func scaleX(_ factor: Double) -> ViewTransform {
        var copy = self
        copy.width *= factor
        return copy
    }

    /// Sizes the view down alone.
    ///
    /// - Parameter factor: 1 is as drawn.
    /// - Returns: the transform, sized down.
    public func scaleY(_ factor: Double) -> ViewTransform {
        var copy = self
        copy.height *= factor
        return copy
    }

    /// Turns the view away about its VERTICAL axis, in degrees - the side
    /// swinging back, which is what puts a gallery's cards on a wheel.
    ///
    ///     .transform { $0.turn(-40).scale(0.86) }
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
        scaleX(ViewTransform.flat(degrees))
    }

    /// Turns the view away about its HORIZONTAL axis, in degrees - the top
    /// swinging back. Drawn flat, exactly as `turn(_:)` is.
    ///
    /// - Parameter degrees: how far to tip away.
    /// - Returns: the transform, tipped away.
    public func tilt(_ degrees: Double) -> ViewTransform {
        scaleY(ViewTransform.flat(degrees))
    }

    /// What a turn of this many degrees looks like drawn flat, never less than
    /// nothing: past a right angle a view is showing its back, which is not a
    /// picture this can make, so the turn stops there.
    ///
    /// - Parameter degrees: the angle.
    /// - Returns: how much of its width is left.
    private static func flat(_ degrees: Double) -> Double {
        let turned = min(abs(degrees), 90) * 3.141592653589793 / 180

        // cos, by hand: this library's own arithmetic all the way down, and
        // nothing here imports a maths library to turn one angle.
        var term = 1.0
        var total = 1.0

        for step in 1...6 {
            let n = Double(2 * step - 1) * Double(2 * step)
            term *= -turned * turned / n
            total += term
        }

        return max(0, total)
    }
}
