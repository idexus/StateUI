// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout's views between the poses its arithmetic answered at keyframes, channel by channel.
// Design: docs/design/views/phase-layout.md#blending-a-pose

/// The poses at an axis's keyframes, blended where the phase stands between them.
enum LayoutBlend {
    /// `runs` - every view's pose, in the views' order, at each of `knots` - blended at `place`, between
    /// `knots[segment]` and the next, along `curve`: each view's bounds, its transform's move, turn, slant and scale,
    /// its opacity and its shade, and the drawing order ranked from the blended `zIndex`.
    static func blend(
        _ runs: [[Placement]], at place: Double, segment: Int, knots: [Double], curve: some LayoutInterpolation
    ) -> [Placement] {
        guard let first = runs.first else { return [] }

        func along(_ values: [Double]) -> Double {
            curve.value(at: place, segment: segment, knots: knots, values: values)
        }

        var blended: [Placement] = []
        var ranks: [Double] = []
        for view in first.indices {
            let poses = runs.map { $0[view] }
            blended.append(pose(poses, along: along))
            ranks.append(along(poses.map { Double($0.zIndex) }))
        }

        let order = ranked(ranks)
        for view in blended.indices { blended[view].zIndex = order[view] }
        return blended
    }

    /// One view's poses blended number by number: sizes at nought at least, opacity and shade inside 0...1, a
    /// layout with no shade left without one.
    private static func pose(_ poses: [Placement], along: ([Double]) -> Double) -> Placement {
        let bounds = Rect(
            along(poses.map(\.bounds.x)),
            along(poses.map(\.bounds.y)),
            max(along(poses.map(\.bounds.width)), 0),
            max(along(poses.map(\.bounds.height)), 0))

        let shade = poses.allSatisfy { $0.shade == Placement.unshaded }
            ? Placement.unshaded
            : min(max(along(poses.map(\.shade)), 0), 1)

        return Placement(
            bounds,
            transform: transform(poses.map(\.transform), along: along),
            opacity: min(max(along(poses.map(\.opacity)), 0), 1),
            shade: shade,
            zIndex: 0)
    }

    /// The transforms blended as their parts, the turn from each to the next the short way; one transform at every
    /// keyframe stays as it is.
    /// Design: docs/design/views/phase-layout.md#blending-a-pose
    private static func transform(_ transforms: [ViewTransform], along: ([Double]) -> Double) -> ViewTransform {
        guard let first = transforms.first, transforms.contains(where: { $0 != first }) else {
            return transforms.first ?? .identity
        }

        let parts = transforms.map(\.parts)
        var turns = parts.map(\.turn)
        for index in turns.indices.dropFirst() {
            let step = turns[index] - turns[index - 1]
            turns[index] -= (step / 360).rounded() * 360
        }

        return ViewTransform(parts: (
            along(parts.map(\.moveX)), along(parts.map(\.moveY)), along(turns), along(parts.map(\.slant)),
            along(parts.map(\.scaleX)), along(parts.map(\.scaleY))))
    }

    /// Each view's drawing rank from its blended number, equal numbers sharing one: views swap as their numbers
    /// cross. A rounding apart is equal.
    private static func ranked(_ numbers: [Double]) -> [Int] {
        let rounded = numbers.map { ($0 * 1e6).rounded() }
        let rank = Dictionary(uniqueKeysWithValues: Set(rounded).sorted().enumerated().map { ($1, $0) })
        return rounded.map { rank[$0] ?? 0 }
    }
}
