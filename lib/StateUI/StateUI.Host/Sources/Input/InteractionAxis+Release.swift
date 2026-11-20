// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A number the hand lets go of: where its throw would end, where it comes to rest, and how it goes on there.
/// Design: docs/design/host/interaction.md#letting-go
extension InteractionAxis {
    /// A number letting go, where the hand works on it - a magnification's logarithm: where the hand held it, how
    /// many points or degrees a unit stands for, its speed in units a second, and where its throw ends.
    public struct Letting: Equatable, Sendable {
        /// Where the hand held the number.
        public let point: Double

        /// How many points or degrees a unit stands for.
        public let per: Double

        /// How fast the hand let go, in units a second.
        public let velocity: Double

        /// Where its throw ends.
        public let end: Double

        /// Whether the hand let go fast enough to throw.
        var throwsFar: Bool { abs(velocity) * per >= InteractionArithmetic.throwing }
    }

    /// How a number goes on to where it rests: its law, its speed in its own units a second, whether it is a
    /// throw, and how far it has left where the hand works on it.
    public struct Going: Equatable, Sendable {
        /// The law it goes on under.
        public let law: Motion

        /// How fast it sets out, in its own units a second.
        public let velocity: Double

        /// Whether it is thrown on, rather than approaching where it rests.
        public let thrown: Bool

        /// How far it has left, where the hand works on it.
        public let left: Double
    }

    /// The number let go at `value`, going `velocity` units a second where the hand works on it, a unit standing for
    /// `per` points or degrees: where its throw would end - inside the range of a number that does not come round,
    /// and where it was let go for a hand too slow to throw, or a release that throws nothing.
    public func letting(at value: Double, per: Double, velocity: Double) -> Letting {
        let point = toHand(value)
        let throwsFar = throwsOn && abs(velocity) * per >= InteractionArithmetic.throwing
        let carried = throwsFar ? point + InteractionArithmetic.carried(velocity, by: throwing) : point
        let end = period == nil ? min(max(carried, toHand(low)), toHand(high)) : carried
        return Letting(point: point, per: per, velocity: velocity, end: end)
    }

    /// Where the number comes to rest let go as `letting` says: a swipe taken at the snap `grip`, the next snap of
    /// its reach the way it was thrown; otherwise where the throw ends, onto the snap nearest it.
    public func rest(of letting: Letting, grip: Double? = nil) -> Double {
        let thrown = throwsOn && letting.throwsFar ? letting.velocity : 0
        if swipes, let grip { return swiped(from: fromHand(letting.point), thrown: thrown, about: grip) }

        return resting(at: fromHand(letting.end), toward: thrown)
    }

    /// Where a swipe taken at the snap `target` and let go at `held` comes to rest: thrown, the next of its reach's
    /// snaps that way - where it was taken or the one beyond; let go still, the nearest of them.
    /// Design: docs/design/host/interaction.md#a-swipe
    public func swiped(from held: Double, thrown: Double, about target: Double) -> Double {
        let reach = reach(about: target)
        let targets = [reach.lowerBound, target, reach.upperBound]
        guard thrown != 0 else { return nearest(of: targets, to: held) }

        let ahead = targets.filter { thrown > 0 ? $0 > held : $0 < held }
        return (thrown > 0 ? ahead.min() : ahead.max()) ?? nearest(of: targets, to: held)
    }

    /// How the number goes on to `value`, let go as `letting` says, its state moving under `own`: thrown on to a
    /// snap ahead from the hand's speed - under the throw's spring, else as a glide no longer than the throw's
    /// longest - where that brings it onto the next snap no slower than `own` moves a unit, and always so with no
    /// snaps; let go still, thrown back or slower than that, it approaches under its release's motion, else `own`,
    /// over as much of its length as the way left is of a unit, the whole of it at most. Nil where it stands there
    /// already, or has no law to go by.
    /// Design: docs/design/host/interaction.md#coming-onto-where-it-rests
    public func going(_ letting: Letting, to value: Double, under own: Motion) -> Going? {
        let left = toHand(value) - letting.point
        let motion = approaching ?? own
        let flight = InteractionArithmetic.flight(left, at: letting.velocity, by: throwing)
        let onward = !hasSnaps || !next(from: fromHand(letting.point), to: value)
            || flight <= InteractionArithmetic.share(of: left) * Double(motion.milliseconds)
        let isThrow = throwsOn && letting.throwsFar && left * letting.velocity > 0 && onward

        guard abs(left) * letting.per > InteractionArithmetic.settled, motion.kind != .custom || isThrow
        else { return nil }

        // The hand's speed as the number goes: its slope where it was let go - a magnification's, by the scale.
        let velocity = (fromHand(letting.point + letting.velocity / 1_000) - fromHand(letting.point)) * 1_000
        guard isThrow else {
            let approach = InteractionArithmetic.approach(motion, over: left)
            guard approach.animates else { return nil }

            let springs = if case .spring = approach.kind { true } else { false }
            return Going(
                law: approach, velocity: springs && left * letting.velocity > 0 ? velocity : 0, thrown: false, left: left)
        }
        if case .spring = throwing.kind { return Going(law: throwing, velocity: velocity, thrown: true, left: left) }

        let longest = InteractionArithmetic.longest(of: throwing)
        return Going(
            law: .glide(longest: .milliseconds(Int(longest.rounded()))), velocity: velocity, thrown: true, left: left)
    }
}
