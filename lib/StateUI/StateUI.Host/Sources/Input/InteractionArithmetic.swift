// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The numbers a hand over a value goes by, the same for every value and every host: how a value gives past an
/// end, how far a throw carries and how long it flies, and how a value approaches where it rests.
/// Design: docs/design/host/interaction.md#the-arithmetic
@_spi(Host) public enum InteractionArithmetic {
    /// The most a value gives past an end, in its units.
    public static let overreach = 0.75

    /// How fast a hand must let go to throw, in points - or degrees, or hundredths of a scale - a second.
    public static let throwing = 50.0

    /// The shortest a throw slows in, in milliseconds.
    public static let shortest = 80.0

    /// How near where it rests a value has to stand to be there already, in points.
    public static let settled = 0.5

    /// How far a wheel's notch moves a value with no snaps, in points.
    public static let notch = 100.0

    /// Where the hand stands for a value at `point`, the ends at `low` and `high`: past one, as far beyond it as
    /// the hand went for the value to give that much.
    public static func pulled(_ point: Double, low: Double, high: Double) -> Double {
        point > high ? high + pulled(point - high) : point < low ? low - pulled(low - point) : point
    }

    /// Where a value stands for the hand at `point`, the ends at `low` and `high`: past one, less and less of the
    /// way beyond it.
    public static func given(_ point: Double, low: Double, high: Double) -> Double {
        point > high ? high + given(point - high) : point < low ? low - given(low - point) : point
    }

    /// How far past an end a value gives for the hand `beyond` it: half as far at first, then less and less, never
    /// `overreach`.
    public static func given(_ beyond: Double) -> Double {
        overreach * (1 - 1 / (beyond / 2 / overreach + 1))
    }

    /// How far past an end the hand went for a value to give `given`: `given(_:)`'s inverse.
    public static func pulled(_ given: Double) -> Double {
        let given = min(given, overreach * 0.999)
        return given / (1 - given / overreach) * 2
    }

    /// The law a throw is timed by: its own, the inherited one 400 milliseconds on `cubicOut`.
    public static func timing(of throwing: Motion) -> Motion {
        throwing.kind == .inherited ? .eased(.milliseconds(400)) : throwing
    }

    /// How much farther a throw at `velocity` units a second carries under `throwing`.
    public static func carried(_ velocity: Double, by throwing: Motion) -> Double {
        HostMotionLaw.carried(velocity, under: timing(of: throwing))
    }

    /// The longest a throw under `throwing` flies, in milliseconds: a glide's own longest; an eased motion's
    /// length twice, the throw going on as a glide; never under `shortest`.
    public static func longest(of throwing: Motion) -> Double {
        let timing = timing(of: throwing)
        let length = Double(timing.milliseconds)
        if case .glide = timing.kind { return max(length, shortest) }
        return max(length * 2, shortest)
    }

    /// How long a throw at `velocity` units a second takes to go `left` on under `throwing`, in milliseconds: the
    /// length that sets it out at the hand's speed, never shorter than `shortest` nor longer than its longest.
    public static func flight(_ left: Double, at velocity: Double, by throwing: Motion) -> Double {
        let setting = velocity == 0
            ? .infinity : abs(left / velocity) * HostMotionLaw.setsOut(timing(of: throwing)) * 1_000

        return min(max(setting, shortest), longest(of: throwing))
    }

    /// `motion` for an approach `left` units long, a unit a length: eased, as long as the way left takes; a
    /// spring, its response cut alike; none for a way that is no number, or a motion that does not animate.
    public static func approach(_ motion: Motion, over left: Double) -> Motion {
        let way = abs(left) * Double(motion.milliseconds)
        let length = Duration.milliseconds(Int64(way.isFinite ? min(way, Double(UInt32.max)).rounded() : 0))

        switch motion.kind {
        case .eased(_, let curve): return .eased(length, curve: curve)
        case .spring(_, let damping): return .spring(Spring(response: length, damping: damping))
        case .glide: return .glide(longest: length)
        case .inherited, .none, .custom: return .none
        }
    }
}
