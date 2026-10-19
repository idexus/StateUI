// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout's arithmetic asked at its axes' keyframes alone, the poses between them blended.
// Design: docs/design/views/layout-engine.md#keyframes

extension LayoutEngine.Run {
    /// Every view's pose at `phase` in `room`, the motion setting out from `from`: the arithmetic's answer where no
    /// axis has keyframes; else blended from its answers at the keyframes around the phase, each asked once.
    /// Design: docs/design/views/layout-engine.md#keyframes
    func pose(in room: Rect, at phase: Phase, from: Phase) -> [Placement] {
        // An axis of no length has one keyframe and no line to go on past it: asked where it stands.
        let keyed = hands.filter { ($0.knots?.count ?? 0) > 1 }
        guard !keyed.isEmpty else { return fitted(arithmetic(room, phase, from)) }

        let blended = Set(keyed.map { $0.index })
        let lanes = Self.lanes(of: phase)
        kept.stand(on: LayoutPoses.Ground(
            room: room, from: readsFrom ? Self.lanes(of: from) : [], followed: followed.map { $0.stamp },
            live: lanes.indices.filter { !blended.contains($0) }.map { lanes[$0] }))
        return pose(in: room, at: phase, from: from, blending: keyed[...])
    }

    /// The pose at `phase`, blended along `axes` one after another; on a keyframe of every one, the arithmetic's own.
    private func pose(
        in room: Rect, at phase: Phase, from: Phase, blending axes: ArraySlice<LayoutEngine.Hand>
    ) -> [Placement] {
        guard let hand = axes.first else {
            return kept.pose(at: Self.lanes(of: phase)) { fitted(arithmetic(room, phase, from)) }
        }

        func at(_ value: Double) -> [Placement] {
            var placed = phase
            placed[keyPath: hand.axis] = value
            return pose(in: room, at: placed, from: from, blending: axes.dropFirst())
        }

        let around = hand.keyframes(around: phase[keyPath: hand.axis], reach: curve.reach)
        if let exact = around.exact { return at(exact) }

        let runs = around.knots.map(at)
        return around.beyond
            ? LayoutBlend.blend(runs, at: around.place, segment: around.segment, knots: around.knots, curve: .linear)
            : LayoutBlend.blend(runs, at: around.place, segment: around.segment, knots: around.knots, curve: curve)
    }

    /// The phase's axes, one number each, in the order `axes` names them.
    static func lanes(of phase: Phase) -> [Double] {
        Phase.axes.map { phase[keyPath: $0] }
    }
}

extension LayoutEngine {
    /// The keyframes a curve reads around a place on an axis: the place - taken into one turn where the axis comes
    /// round - the keyframe before it among them, the keyframe it stands on, if one, and whether it is past an end
    /// of the range, where the end's straight line goes on.
    struct KeyframesAround {
        let knots: [Double]
        let place: Double
        let segment: Int
        let exact: Double?
        let beyond: Bool
    }
}

extension LayoutEngine.Hand {
    /// The keyframes around `value` a curve reaching `reach` either side reads: across the seam, the next or last
    /// turn's, where the axis comes round; past an end, the end's two.
    /// Design: docs/design/views/layout-engine.md#keyframes
    func keyframes(around value: Double, reach: Int) -> LayoutEngine.KeyframesAround {
        guard let knots, knots.count > 1 else {
            return .init(knots: [], place: value, segment: 0, exact: value, beyond: false)
        }

        // A keyframe a rounding from the place is the place.
        func exact(_ candidates: [Double], _ place: Double) -> Double? {
            candidates.first { abs($0 - place) <= 1e-9 * max(abs($0), abs(place), 1) }
        }

        if let period {
            // One turn's keyframes: the last is the next turn's first.
            let turn = Array(knots.dropLast())
            let place = low + (value - low) - ((value - low) / period).rounded(.down) * period
            let segment = turn.lastIndex { $0 <= place } ?? 0
            let around = ((segment - reach)...(segment + 1 + reach)).map { index in
                let at = (index % turn.count + turn.count) % turn.count
                return turn[at] + Double((index - at) / turn.count) * period
            }
            return .init(
                knots: around, place: place, segment: reach, exact: exact([around[reach], around[reach + 1]], place),
                beyond: false)
        }

        if value < low || value > high {
            let segment = value < low ? 0 : knots.count - 2
            return .init(
                knots: [knots[segment], knots[segment + 1]], place: value, segment: 0, exact: nil, beyond: true)
        }

        let segment = min(knots.lastIndex { $0 <= value } ?? 0, knots.count - 2)
        let (first, last) = (max(segment - reach, 0), min(segment + 1 + reach, knots.count - 1))
        return .init(
            knots: Array(knots[first...last]), place: value, segment: segment - first,
            exact: exact([knots[segment], knots[segment + 1]], value), beyond: false)
    }
}
