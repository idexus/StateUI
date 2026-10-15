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
#elseif canImport(WASILibc)
import WASILibc
#endif

/// How far a view stands from where its arithmetic puts it, channel by channel: what a change of a layout's
/// description at the current phase leaves, laid over the view's pose and decaying to nothing under the layout's
/// motion.
/// Design: docs/design/views/layout-engine.md#a-change-at-the-current-phase
struct LayoutShift: Equatable, Sendable {
    /// The numbers, lane by lane: the bounds' place and size; the transform's correction - a move across and down,
    /// a turn in degrees, a slant and a scale across and down less one; the opacity; the shade.
    var lanes: [Double]

    /// Where each part stands among the lanes.
    static let x = 0, y = 1, width = 2, height = 3
    static let moveX = 4, moveY = 5, turn = 6, slant = 7, scaleX = 8, scaleY = 9
    static let opacity = 10, shade = 11

    /// How many lanes a shift has.
    static let count = 12

    /// No shift: the view where its arithmetic puts it.
    static let none = LayoutShift(lanes: Array(repeating: 0, count: count))

    init(lanes: [Double]) {
        self.lanes = lanes
    }

    /// The shift that shows `pose` where `shown` stood: the bounds and the opacity apart, the transform as the
    /// correction that takes the pose's to the one shown - the turn the short way - and the shade only where both
    /// draw one.
    init(from shown: Placement, to pose: Placement) {
        var lanes = LayoutShift.none.lanes
        lanes[Self.x] = shown.bounds.x - pose.bounds.x
        lanes[Self.y] = shown.bounds.y - pose.bounds.y
        lanes[Self.width] = shown.bounds.width - pose.bounds.width
        lanes[Self.height] = shown.bounds.height - pose.bounds.height

        if let correction = pose.transform.inverted.map({ $0.then(shown.transform) }) {
            let parts = correction.parts
            lanes[Self.moveX] = parts.moveX
            lanes[Self.moveY] = parts.moveY
            lanes[Self.turn] = parts.turn
            lanes[Self.slant] = parts.slant
            lanes[Self.scaleX] = parts.scaleX - 1
            lanes[Self.scaleY] = parts.scaleY - 1
        }

        lanes[Self.opacity] = shown.opacity - pose.opacity
        if shown.shade != PackedPlacement.unshaded, pose.shade != PackedPlacement.unshaded {
            lanes[Self.shade] = shown.shade - pose.shade
        }
        self.lanes = lanes
    }

    /// A view joining: where its arithmetic puts it, with nothing of it shown yet.
    static func joining(_ pose: Placement) -> LayoutShift {
        var joining = LayoutShift.none
        joining.lanes[opacity] = -pose.opacity
        return joining
    }

    /// `pose` shifted: its bounds and opacity moved by the lanes, its transform corrected after it, its order its
    /// own.
    func applied(to pose: Placement) -> Placement {
        guard self != .none else { return pose }

        var shifted = pose
        shifted.bounds = Rect(
            pose.bounds.x + lanes[Self.x], pose.bounds.y + lanes[Self.y],
            pose.bounds.width + lanes[Self.width], pose.bounds.height + lanes[Self.height])
        shifted.transform = pose.transform.then(ViewTransform(parts: (
            lanes[Self.moveX], lanes[Self.moveY], lanes[Self.turn], lanes[Self.slant],
            lanes[Self.scaleX] + 1, lanes[Self.scaleY] + 1)))
        shifted.opacity = min(max(pose.opacity + lanes[Self.opacity], 0), 1)
        if pose.shade != PackedPlacement.unshaded {
            shifted.shade = min(max(pose.shade + lanes[Self.shade], 0), 1)
        }
        return shifted
    }
}

/// A shift on its way to nothing: where its lanes stood and how fast they went as it set out, and when.
struct LayoutTravel: Equatable, Sendable {
    var from: [Double]
    var velocity: [Double]
    var began: Double

    /// Where the shift stands at `now` under `law`, how fast it goes, per millisecond, and whether it has come to
    /// nothing.
    func at(_ now: Double, under law: Motion) -> HostMotionSample {
        HostMotionLaw.sample(
            law, elapsed: max(now - began, 0), from: from, destination: Array(repeating: 0, count: from.count),
            velocity: velocity)
    }
}

/// A transform as parts the way back can be measured in.
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

    /// This transform, then `next` after it.
    func then(_ next: ViewTransform) -> ViewTransform {
        var both = ViewTransform()
        both.a = next.a * a + next.c * b
        both.b = next.b * a + next.d * b
        both.c = next.a * c + next.c * d
        both.d = next.b * c + next.d * d
        both.tx = next.a * tx + next.c * ty + next.tx
        both.ty = next.b * tx + next.d * ty + next.ty
        return both
    }

    /// The transform as a scale, then a slant along, then a turn in degrees - the short way, at most half a turn -
    /// then a move: each part a number the way back can be measured in.
    var parts: (moveX: Double, moveY: Double, turn: Double, slant: Double, scaleX: Double, scaleY: Double) {
        let scaleX = (a * a + b * b).squareRoot()
        let turned = atan2(b, a)
        let along = cos(turned) * c + sin(turned) * d
        let scaleY = -sin(turned) * c + cos(turned) * d
        return (tx, ty, turned * 180 / Double.pi, scaleY == 0 ? 0 : along / scaleY, scaleX, scaleY)
    }

    /// The transform the parts make: scaled, slanted, turned, then moved.
    init(parts: (moveX: Double, moveY: Double, turn: Double, slant: Double, scaleX: Double, scaleY: Double)) {
        let turned = parts.turn * Double.pi / 180
        let (run, rise) = (cos(turned), sin(turned))

        self.init()
        a = run * parts.scaleX
        b = rise * parts.scaleX
        c = run * parts.slant * parts.scaleY - rise * parts.scaleY
        d = rise * parts.slant * parts.scaleY + run * parts.scaleY
        tx = parts.moveX
        ty = parts.moveY
    }
}
