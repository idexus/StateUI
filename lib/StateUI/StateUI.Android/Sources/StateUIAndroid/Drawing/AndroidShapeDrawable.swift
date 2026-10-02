// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A shape filled with a brush and outlined: the host's `StateUIShapeDrawable`, told every part by Swift as the host
/// layer reads a box (`BoxArithmetic`, `HostBrush`) - its corners fitted to the size it is drawn at.
/// Design: docs/design/platforms/android/drawing.md#a-shape-and-its-brush
@MainActor
final class AndroidShapeDrawable {
    /// A shape's outline: a rectangle, one with rounded corners, or an ellipse.
    enum Shape: Equatable {
        case rectangle

        /// The corners' radii in points, clockwise from the top left.
        case rounded([Double])

        case ellipse

        /// A layout's or a button's outline as the tree's `value` asks for it.
        init(container value: HostValue?) {
            switch BoxArithmetic.outline(value) {
            case .rectangle: self = .rectangle
            case .roundedRectangle(let radius): self = .rounded([radius, radius, radius, radius])
            case .ellipse: self = .ellipse
            }
        }

        /// A box's own corners; a rectangle where none are said.
        init(corners: CornerRadius?) {
            self = corners == nil ? .rectangle : .rounded(BoxArithmetic.clockwise(corners))
        }

        /// The Java side's kind, and each corner's width and height in pixels, clockwise from the top left: no more
        /// than half the side it rounds of a room `size` pixels, where the size is known.
        func drawn(density: Double, in size: (width: Double, height: Double)?) -> (kind: Int32, radii: [Float]) {
            switch self {
            case .rectangle: (0, Array(repeating: 0, count: 8))
            case .ellipse: (2, Array(repeating: 0, count: 8))
            case .rounded(let radii):
                (1, radii.flatMap { radius -> [Float] in
                    let pixels = radius * density
                    guard let size else { return [Float(pixels), Float(pixels)] }
                    let fitted = BoxArithmetic.fitted(pixels, width: size.width, height: size.height)
                    return [Float(fitted.width), Float(fitted.height)]
                })
            }
        }
    }

    /// The drawable, held until this is released.
    let object = Java.new(JavaAPI.shapeDrawable, JavaAPI.newShapeDrawable)

    var reference: jobject { object.reference }

    private var shape = Shape.rectangle
    private var density = 1.0

    /// The size the drawable is drawn at, in pixels; nil before its view is placed.
    private var size: (width: Int32, height: Int32)?

    /// The outline's width in pixels, which the shape stands inside of.
    private var lineWidth = 0.0

    /// The radii last told the Java side.
    private var told: (kind: Int32, radii: [Float])?

    /// What fills the shape, as the tree gave it.
    private var fill: HostValue?

    /// The shape, its radii in points turned into pixels at `density`.
    func setShape(_ shape: Shape, density: Double) {
        self.shape = shape
        self.density = density
        tellShape()
    }

    /// The size the drawable is drawn at, in pixels: its corners are fitted to it.
    func fit(width: Int32, height: Int32) {
        guard size.map({ $0 != (width, height) }) ?? true else { return }
        size = (width, height)
        tellShape()
        if case .radial = HostBrush(fill) { tellFill() }
    }

    /// Tells the Java side the shape, its corners fitted within the outline where the drawable's size is known.
    private func tellShape() {
        let room = size.map { (Double($0.width) - lineWidth, Double($0.height) - lineWidth) }
        let drawn = shape.drawn(density: density, in: room)
        guard told.map({ $0.kind != drawn.kind || $0.radii != drawn.radii }) ?? true else { return }
        told = drawn
        let radii = Java.floats(drawn.radii)
        Java.call(reference, JavaAPI.setShape, .int(drawn.kind), .object(radii))
        Java.release(local: radii)
    }

    /// What fills the shape: a colour, or a brush as it crosses; nil for nothing.
    func setFill(_ value: HostValue?) {
        fill = value
        tellFill()
    }

    /// Tells the Java side the fill, a radial gradient reaching as far as the size the drawable is drawn at says.
    private func tellFill() {
        let brush = Self.brush(fill, over: size.map { (Double($0.width), Double($0.height)) })
        let colors = Java.ints(brush.colors)
        let offsets = Java.floats(brush.offsets)
        let fractions = Java.floats(brush.geometry)
        Java.call(reference, JavaAPI.setFill, .int(brush.kind), .object(colors), .object(offsets), .object(fractions))
        Java.release(local: fractions)
        Java.release(local: offsets)
        Java.release(local: colors)
    }

    /// A brush as the Java side takes it, from the host layer's reading of it: its kind, then a colour and an offset
    /// for each stop, and its geometry - points in fractions of the shape, a radial gradient's reach in pixels over
    /// `size` (`HostBrush.reach`), none before the size is known.
    /// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
    static func brush(
        _ value: HostValue?, over size: (width: Double, height: Double)?
    ) -> (kind: Int32, colors: [Int32], offsets: [Float], geometry: [Float]) {
        func stops(_ stops: [HostBrush.Stop]) -> (colors: [Int32], offsets: [Float]) {
            let drawn = stops.compactMap { stop in AndroidView.argb(stop.color).map { ($0, Float(stop.offset)) } }
            return (drawn.map(\.0), drawn.map(\.1))
        }

        switch HostBrush(value) {
        case .none:
            return (0, [], [], [])
        case .solid(let color):
            return AndroidView.argb(color).map { (1, [$0], [0], []) } ?? (0, [], [], [])
        case .linear(let from, let to, let run):
            let (colors, offsets) = stops(run)
            return (2, colors, offsets, [from.x, from.y, to.x, to.y].map(Float.init))
        case .radial(let center, let radius, let run):
            let (colors, offsets) = stops(run)
            let reach = size.map { HostBrush.reach(of: radius, width: $0.width, height: $0.height) } ?? 0
            return (3, colors, offsets, [center.x, center.y, reach].map(Float.init))
        }
    }

    /// The outline: the brush's colour, `width` points wide as the host layer reads it - one where none is said,
    /// none without a colour - at `density`.
    func setStroke(_ value: HostValue?, width: Double?, density: Double) {
        let argb = HostBrush(value).firstColor.flatMap(AndroidView.argb)
        lineWidth = argb == nil ? 0 : BoxArithmetic.outlineWidth(stroke: value, width: width) * density
        Java.call(reference, JavaAPI.setStroke, .int(argb ?? 0), .float(Float(lineWidth)))
        tellShape()
    }
}
