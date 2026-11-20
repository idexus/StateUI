// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIFoundation
@_spi(Host) import StateUI

/// One number a hand moves, with the arithmetic of where it may stand and rest: its ends, its snaps - a list, or
/// every multiple of a step - its turn where it comes round, and the logarithm a magnification is worked on in.
/// Design: docs/design/host/interaction.md#one-number
@_spi(Host) public struct InteractionAxis: Equatable, Sendable {
    /// The number as the program declares it.
    public let value: HostInteractionValue

    /// The axis of `value`.
    public init(_ value: HostInteractionValue) {
        self.value = value
    }

    /// The lower end of its range; minus infinity for none.
    public var low: Double { value.low }

    /// The upper end of its range; infinity for none.
    public var high: Double { value.high }

    /// How far one turn takes it, where it comes round.
    public var period: Double? { value.periodic && high > low && (high - low).isFinite ? high - low : nil }

    /// Which way it grows under the hand: with it, or - reversed - against it.
    public var sense: Double { value.reversed ? -1 : 1 }

    /// Whether it rests on snaps.
    public var hasSnaps: Bool { value.snaps != nil }

    /// Whether the hand moves it one snap at most.
    public var swipes: Bool {
        if case .translation(_, _, true) = value.input { return true }
        return false
    }

    /// Whether the hand moves it across, where a hand does.
    public var across: Bool {
        if case .translation(.vertical, _, _) = value.input { return false }
        return true
    }

    /// How far the hand travels for a unit of it, where a hand moves it.
    public var unit: InteractionUnit? {
        if case .translation(_, let unit, _) = value.input { return unit }
        return nil
    }

    /// Whether it is moved by its logarithm: a magnification, multiplied by the fingers.
    public var multiplies: Bool { value.input == .magnification }

    /// A value where the hand works on it: its logarithm for a magnification.
    public func toHand(_ value: Double) -> Double { multiplies ? log(max(value, .leastNormalMagnitude)) : value }

    /// A place where the hand works, as the number's own value.
    public func fromHand(_ point: Double) -> Double { multiplies ? exp(point) : point }

    /// The motion a throw of it goes by.
    public var throwing: Motion {
        if case .projected(let motion) = value.release { return motion }
        return .eased(.milliseconds(400))
    }

    /// Whether letting it go throws it at all.
    public var throwsOn: Bool {
        if case .projected = value.release { return true }
        return false
    }

    /// Whether it stays where it was left.
    public var stays: Bool { value.release == .stay }

    /// The motion it comes onto the nearest under, where its release names one.
    public var approaching: Motion? {
        if case .nearest(let motion) = value.release { return motion }
        return nil
    }

    // MARK: - Where it may rest

    /// Its snaps near `value`, lowest first: a list as it comes round - the turn `value` stands in and one either
    /// side - or the multiples of a step about it. None for a number with no snaps.
    public func snaps(near value: Double) -> [Double] {
        switch self.value.snaps {
        case nil:
            return []
        case .at(let listed)?:
            guard let period else { return listed }

            let turn = ((value - low) / period).rounded(.down)
            return [turn - 1, turn, turn + 1].flatMap { turn in listed.map { $0 + turn * period } }
        case .every(let step)?:
            guard step > 0, value.isFinite else { return [] }

            let below = (value / step).rounded(.down)
            return [below - 1, below, below + 1, below + 2].map { $0 * step }.filter { $0 >= low && $0 <= high }
        }
    }

    /// Of `values`, the one nearest `value` where the hand works on them; of two as near, the one the hand was
    /// going toward at `velocity`, the lower for a hand standing still.
    public func nearest(of values: [Double], to value: Double, toward velocity: Double = 0) -> Double {
        let point = toHand(value)
        var best: Double?
        for each in values {
            guard let found = best else {
                best = each
                continue
            }
            let (gap, least) = (abs(toHand(each) - point), abs(toHand(found) - point))
            if gap < least || gap == least && (velocity > 0 ? each > found : each < found) { best = each }
        }
        return best ?? value
    }

    /// The snap nearest `value`; `value` itself for a number with no snaps.
    public func nearest(_ value: Double, toward velocity: Double = 0) -> Double {
        nearest(of: snaps(near: value), to: value, toward: velocity)
    }

    /// Where the number comes to rest from `value`: the snap nearest, or - with none - `value` itself, inside the
    /// range of a number that does not come round.
    public func resting(at value: Double, toward velocity: Double = 0) -> Double {
        guard !hasSnaps else { return nearest(value, toward: velocity) }

        return period == nil ? min(max(value, low), high) : value
    }

    /// Whether `to` is the next snap from `from`: none stands between them.
    public func next(from: Double, to: Double) -> Bool {
        let (least, most) = (min(from, to), max(from, to))
        if case .every(let step)? = value.snaps, step > 0 {
            return !(((least / step).rounded(.down) + 1) * step < most)
        }
        return !snaps(near: from).contains { least < $0 && $0 < most }
    }

    /// The snap `count` on from the one nearest `value` - back for fewer than nought - held to the ends of a number
    /// that does not come round, a turn on or back where it does.
    public func stepped(_ value: Double, by count: Int) -> Double {
        switch self.value.snaps {
        case nil:
            return value
        case .every(let step)?:
            guard step > 0 else { return value }
            return min(max(((value / step).rounded() + Double(count)) * step, low), high)
        case .at(let listed)?:
            guard !listed.isEmpty else { return value }

            let turns: [Double] = period.map { period in
                let turn = ((value - low) / period).rounded(.down)
                return [turn - 1, turn, turn + 1]
            } ?? [0]
            var nearest = (turn: 0.0, index: 0, gap: Double.infinity)
            for turn in turns {
                for (index, stop) in listed.enumerated() {
                    let gap = abs(stop + turn * (period ?? 0) - value)
                    if gap < nearest.gap { nearest = (turn, index, gap) }
                }
            }

            let moved = nearest.index + count
            guard let period else { return listed[min(max(moved, 0), listed.count - 1)] }

            let round = (Double(moved) / Double(listed.count)).rounded(.down)
            return listed[moved - Int(round) * listed.count] + (nearest.turn + round) * period
        }
    }

    // MARK: - Under the hand

    /// Where the number stands once the hand moved it `step` of its unit from `held`, where the hand works on it:
    /// less and less past an end of a number that does not come round, and no farther than `reach`.
    /// Design: docs/design/host/interaction.md#past-an-end
    public func moved(from held: Double, by step: Double, within reach: ClosedRange<Double>? = nil) -> Double {
        let point = toHand(held)
        let (low, high) = (toHand(self.low), toHand(self.high))
        let free = fromHand(period != nil ? point + step : InteractionArithmetic.given(
            InteractionArithmetic.pulled(point, low: low, high: high) + step, low: low, high: high))
        return reach.map { min(max(free, $0.lowerBound), $0.upperBound) } ?? free
    }

    /// How far a swiping hand that took the number at the snap `target` moves it: from the snap before to the one
    /// after.
    /// Design: docs/design/host/interaction.md#a-swipe
    public func reach(about target: Double) -> ClosedRange<Double> {
        let (before, after) = (stepped(target, by: -1), stepped(target, by: 1))
        return min(before, after)...max(before, after)
    }

    /// Where `count` notches of a wheel take a number with no snaps from `value`, a unit standing for `per`
    /// points: as far as a hand going a notch's travel for each moves it.
    public func notched(_ value: Double, by count: Int, per: Double?) -> Double {
        let moved = value + Double(count) * InteractionArithmetic.notch / (per ?? InteractionArithmetic.notch)
        return period == nil ? min(max(moved, low), high) : moved
    }
}
