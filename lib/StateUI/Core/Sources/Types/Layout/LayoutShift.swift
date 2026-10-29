// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for `sin`, `cos` and `atan2`, not Foundation.
// Design: docs/design/types/transforms.md#the-arithmetic-is-in-the-core
import StateUIFoundation

/// How far a view stands from where its arithmetic puts it, channel by channel: what a change of a layout's
/// description at the current phase leaves, laid over the view's pose and decaying to nothing under the layout's
/// motion.
/// Design: docs/design/views/phase-layout.md#a-change-at-the-current-phase
struct LayoutShift: Equatable, Sendable {
    /// The numbers, lane by lane: the bounds' place and size; the transform's five drawn numbers apart - its move
    /// across and down, its turn in degrees, its width and height; the opacity; the shade.
    var lanes: [Double]

    /// Where each part stands among the lanes.
    static let x = 0, y = 1, width = 2, height = 3
    static let moveX = 4, moveY = 5, turn = 6, scaleX = 7, scaleY = 8
    static let opacity = 9, shade = 10

    /// How many lanes a shift has.
    static let count = 11

    /// No shift: the view where its arithmetic puts it.
    static let none = LayoutShift(lanes: Array(repeating: 0, count: count))

    init(lanes: [Double]) {
        self.lanes = lanes
    }

    /// The shift that shows `pose` where `shown` stood: the bounds, the opacity and the transform's five drawn numbers
    /// apart - the turn the short way, as a view's own transform travels - and the shade only where both draw one.
    /// Design: docs/design/types/transforms.md#the-shear-limit
    init(from shown: Placement, to pose: Placement) {
        var lanes = LayoutShift.none.lanes
        lanes[Self.x] = shown.bounds.x - pose.bounds.x
        lanes[Self.y] = shown.bounds.y - pose.bounds.y
        lanes[Self.width] = shown.bounds.width - pose.bounds.width
        lanes[Self.height] = shown.bounds.height - pose.bounds.height

        let (from, to) = (shown.transform, pose.transform)
        let turn = from.rotation - to.rotation
        lanes[Self.moveX] = from.x - to.x
        lanes[Self.moveY] = from.y - to.y
        lanes[Self.turn] = turn - (turn / 360).rounded() * 360
        lanes[Self.scaleX] = from.width - to.width
        lanes[Self.scaleY] = from.height - to.height

        lanes[Self.opacity] = shown.opacity - pose.opacity
        if shown.shade != Placement.unshaded, pose.shade != Placement.unshaded {
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

    /// `pose` shifted: its bounds, opacity and the transform's five drawn numbers moved by the lanes, its order its
    /// own.
    func applied(to pose: Placement) -> Placement {
        guard self != .none else { return pose }

        var shifted = pose
        shifted.bounds = Rect(
            pose.bounds.x + lanes[Self.x], pose.bounds.y + lanes[Self.y],
            pose.bounds.width + lanes[Self.width], pose.bounds.height + lanes[Self.height])
        let transform = pose.transform
        shifted.transform = ViewTransform(
            x: transform.x + lanes[Self.moveX], y: transform.y + lanes[Self.moveY],
            rotation: transform.rotation + lanes[Self.turn], width: transform.width + lanes[Self.scaleX],
            height: transform.height + lanes[Self.scaleY])
        shifted.opacity = min(max(pose.opacity + lanes[Self.opacity], 0), 1)
        if pose.shade != Placement.unshaded {
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

    /// Where the shift stands at `now` under `law`, how fast it goes, per second, and whether it has come to
    /// nothing.
    func at(_ now: Double, under law: Motion) -> HostMotionSample {
        HostMotionLaw.sample(
            law, elapsed: max(now - began, 0), from: from, destination: Array(repeating: 0, count: from.count),
            velocity: velocity)
    }
}

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
