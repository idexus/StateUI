// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A shape filled with a brush and outlined: the host's `StateUIShapeDrawable`, told every part by Swift.
/// Design: docs/design/platforms/android/drawing.md#a-shape-and-its-brush
@MainActor
final class AndroidShapeDrawable {
    /// A shape's outline: a rectangle, one with rounded corners, or an ellipse.
    enum Shape: Equatable {
        case rectangle

        /// The corners' radii in points: top left, top right, bottom right, bottom left.
        case rounded([Double])

        case ellipse

        /// A Border's shape as it crosses: its kind, then a rectangle's radius.
        init(border value: HostValue?) {
            guard let parts = value?.values, let kind = parts.first?.enumeration else {
                self = .rectangle
                return
            }

            switch kind {
            case 1:
                let radius = max(0, parts.value(1)?.number ?? 0)
                self = .rounded([radius, radius, radius, radius])
            case 2: self = .ellipse
            default: self = .rectangle
            }
        }

        /// A corner radius as it crosses: one for every corner, or four in StateUI's order -
        /// top left, top right, bottom left, bottom right.
        init(corners value: HostValue?) {
            if let radius = value?.number {
                self = .rounded([radius, radius, radius, radius].map(Self.sanitized))
            } else if let radii = value?.numbers, radii.count >= 4 {
                self = .rounded([radii[0], radii[1], radii[3], radii[2]].map(Self.sanitized))
            } else {
                self = .rectangle
            }
        }

        private static func sanitized(_ radius: Double) -> Double {
            radius.isFinite ? max(0, radius) : 0
        }
    }

    /// The drawable, held until this is released.
    let object = Java.new(JavaAPI.shapeDrawable, JavaAPI.newShapeDrawable)

    var reference: jobject { object.reference }

    /// The shape, its radii in points turned into pixels at `density`.
    func setShape(_ shape: Shape, density: Double) {
        let (kind, radii): (Int32, [Double]) = switch shape {
        case .rectangle: (0, [0, 0, 0, 0])
        case .rounded(let radii): (1, radii)
        case .ellipse: (2, [0, 0, 0, 0])
        }

        let corners = Java.floats(radii.map { Float($0 * density) })
        Java.call(reference, JavaAPI.setShape, .int(kind), .object(corners))
        Java.release(local: corners)
    }

    /// What fills the shape: a colour, or a brush as it crosses; nil for nothing.
    func setFill(_ value: HostValue?) {
        let brush = Self.brush(value)
        let colors = Java.ints(brush.colors)
        let offsets = Java.floats(brush.offsets)
        let fractions = Java.floats(brush.geometry)
        Java.call(reference, JavaAPI.setFill, .int(brush.kind), .object(colors), .object(offsets), .object(fractions))
        Java.release(local: fractions)
        Java.release(local: offsets)
        Java.release(local: colors)
    }

    /// A brush as the Java side takes it: its kind, then a colour and an offset for each stop, and its
    /// geometry in fractions of the shape - from a colour, or a brush as it crosses: its kind, its geometry,
    /// then an offset and a colour for each stop.
    /// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
    static func brush(_ value: HostValue?) -> (kind: Int32, colors: [Int32], offsets: [Float], geometry: [Float]) {
        if let value, let argb = AndroidView.argb(value) { return (1, [argb], [0], []) }
        guard let parts = value?.values, let brush = parts.first?.enumeration else { return (0, [], [], []) }

        if brush == 1 {
            let argb = parts.value(1).flatMap(AndroidView.argb)
            return (1, argb.map { [$0] } ?? [], argb == nil ? [] : [0], [])
        }
        var colors: [Int32] = []
        var offsets: [Float] = []
        var index = 2
        while index + 1 < parts.count, let offset = parts[index].number, let argb = AndroidView.argb(parts[index + 1]) {
            colors.append(argb)
            offsets.append(Float(min(max(offset, 0), 1)))
            index += 2
        }
        return (brush, colors, offsets, (parts.value(1)?.numbers ?? []).map(Float.init))
    }

    /// The outline: a colour, or a brush's first colour, `width` pixels wide; none for nil.
    func setStroke(_ value: HostValue?, width: Double) {
        let argb = value.flatMap { value in
            AndroidView.argb(value) ?? value.values?.lazy.compactMap(AndroidView.argb).first
        }
        Java.call(reference, JavaAPI.setStroke, .int(argb ?? 0), .float(argb == nil ? 0 : Float(width)))
    }
}
