// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for the spring's `exp`, `sin` and `cos`.
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// The two motion laws as numbers, in closed form in the time since an animation
// began. Every runtime animates with these; `Tests/Fixtures/motion-laws.txt`
// pins their numbers.
// Design: docs/design/core/journeys.md#motion-laws

/// Where an animation stands at one instant of its law.
@_spi(Host) public struct HostMotionSample: Equatable, Sendable {
    /// The value of each lane.
    public let value: [Double]

    /// How fast each lane is going, per millisecond.
    public let velocity: [Double]

    /// Whether the animation has arrived: every lane at its destination and still.
    public let rested: Bool
}

/// The two motion laws, evaluated from the time since an animation began.
///
/// Time is in milliseconds, the unit of `Motion`'s numbers, so velocity is per
/// millisecond. A journey reports its velocity per second; an animator converts
/// where it reports.
@_spi(Host) public enum HostMotionLaw {
    /// How near its destination and how slow a lane is when it counts as arrived: in
    /// the value's own units, and per millisecond for the speed. A thousandth of a
    /// colour channel or of a point is below any display's resolution.
    public static let still = 0.001

    /// The longest a spring animates, in milliseconds. A spring has no stated end;
    /// this keeps any animation from holding a display clock awake for ever.
    public static let longest = 10_000.0

    /// Where an animation stands `elapsed` milliseconds after it began.
    ///
    /// An eased animation from a standstill follows its curve exactly. A lane that
    /// began moving follows the cubic Hermite of the same length instead, from the
    /// value and speed it had to its destination at a standstill. A spring settles
    /// each lane on its own, and the animation rests when all of them have.
    ///
    /// - Parameters:
    ///   - motion: The law and its numbers.
    ///   - elapsed: Milliseconds since the animation began.
    ///   - from: Where each lane began.
    ///   - destination: Where each lane is going.
    ///   - velocity: How fast each lane was going when it began, per
    ///     millisecond.
    /// - Returns: The value and velocity at that instant, and whether the
    ///   animation has arrived. Lanes that do not pair up land at once.
    public static func sample(
        _ motion: Motion,
        elapsed: Double,
        from: [Double],
        destination: [Double],
        velocity: [Double]
    ) -> HostMotionSample {
        guard from.count == destination.count, from.count == velocity.count else {
            return landed(destination)
        }

        switch motion.law {
        case .eased:
            return eased(
                length: Double(motion.millis),
                curve: motion.curve,
                elapsed: elapsed,
                from: from,
                destination: destination,
                velocity: velocity)
        case .spring:
            return spring(
                response: Double(max(motion.millis, 1)),
                damping: max(motion.factor, 0.01),
                elapsed: elapsed,
                from: from,
                destination: destination,
                velocity: velocity)
        }
    }

    /// An animation at its destination, standing still.
    private static func landed(_ destination: [Double]) -> HostMotionSample {
        HostMotionSample(
            value: destination,
            velocity: Array(repeating: 0, count: destination.count),
            rested: true)
    }

    private static func eased(
        length: Double,
        curve: Easing,
        elapsed: Double,
        from: [Double],
        destination: [Double],
        velocity: [Double]
    ) -> HostMotionSample {
        guard length > 0, elapsed < length else { return landed(destination) }

        let progress = elapsed / length
        let amount = ease(curve, at: progress)
        let climb = slope(curve, at: progress)

        // The Hermite basis and its derivative, which only a lane that began
        // moving needs.
        let h00 = ((2 * progress) - 3) * progress * progress + 1
        let h10 = ((progress - 2) * progress + 1) * progress
        let h01 = (3 - (2 * progress)) * progress * progress
        let d00 = (6 * progress * progress) - (6 * progress)
        let d10 = (3 * progress * progress) - (4 * progress) + 1
        let d01 = (6 * progress) - (6 * progress * progress)

        var value = Array(repeating: 0.0, count: from.count)
        var speed = value

        for lane in value.indices {
            if velocity[lane] == 0 {
                value[lane] = from[lane] + ((destination[lane] - from[lane]) * amount)
                speed[lane] = (destination[lane] - from[lane]) * climb / length
            } else {
                value[lane] = (h00 * from[lane])
                    + (h10 * length * velocity[lane])
                    + (h01 * destination[lane])
                speed[lane] = ((d00 * from[lane])
                    + (d10 * length * velocity[lane])
                    + (d01 * destination[lane])) / length
            }
        }

        return HostMotionSample(value: value, velocity: speed, rested: false)
    }

    /// A mass on a spring, in closed form about the distance left rather than
    /// the value - which makes the three damping cases the textbook ones and
    /// keeps the destination out of the exponentials.
    private static func spring(
        response: Double,
        damping: Double,
        elapsed: Double,
        from: [Double],
        destination: [Double],
        velocity: [Double]
    ) -> HostMotionSample {
        guard elapsed < longest else { return landed(destination) }

        let frequency = 2 * Double.pi / response
        var value = Array(repeating: 0.0, count: from.count)
        var speed = value
        var rested = true

        for lane in value.indices {
            let target = destination[lane]
            let displacement = from[lane] - target
            let initialSpeed = velocity[lane]
            let remaining: Double
            let derivative: Double

            if abs(damping - 1) < 1e-6 {
                let b = initialSpeed + (frequency * displacement)
                let decay = exp(-frequency * elapsed)
                remaining = (displacement + (b * elapsed)) * decay
                derivative = (b - (frequency * (displacement + (b * elapsed)))) * decay
            } else if damping < 1 {
                let damped = frequency * sqrt(1 - (damping * damping))
                let a = displacement
                let b = (initialSpeed + (damping * frequency * displacement)) / damped
                let decay = exp(-damping * frequency * elapsed)
                let cosine = cos(damped * elapsed)
                let sine = sin(damped * elapsed)
                remaining = decay * ((a * cosine) + (b * sine))
                derivative = decay * (
                    (-damping * frequency * ((a * cosine) + (b * sine)))
                        + (damped * ((b * cosine) - (a * sine))))
            } else {
                let root = frequency * sqrt((damping * damping) - 1)
                let first = -(frequency * damping) + root
                let second = -(frequency * damping) - root
                let c1 = (initialSpeed - (second * displacement)) / (first - second)
                let c2 = displacement - c1
                remaining = (c1 * exp(first * elapsed)) + (c2 * exp(second * elapsed))
                derivative = (c1 * first * exp(first * elapsed))
                    + (c2 * second * exp(second * elapsed))
            }

            if abs(remaining) <= still && abs(derivative) <= still {
                value[lane] = target
                speed[lane] = 0
            } else {
                value[lane] = target + remaining
                speed[lane] = derivative
                rested = false
            }
        }

        return rested
            ? landed(destination)
            : HostMotionSample(value: value, velocity: speed, rested: false)
    }

    /// How far through the change an eased animation is when `progress` of its
    /// length has passed: 0 at the start and 1 at the end, and past 1 and back on the
    /// curves that overshoot.
    static func ease(_ curve: Easing, at progress: Double) -> Double {
        let value = min(max(progress, 0), 1)

        switch curve {
        case .linear:
            return value
        case .sineOut:
            return sin(value * .pi / 2)
        case .sineIn:
            return 1 - cos(value * .pi / 2)
        case .sineInOut:
            return (1 - cos(value * .pi)) / 2
        case .cubicIn:
            return value * value * value
        case .cubicOut:
            let shifted = value - 1
            return (shifted * shifted * shifted) + 1
        case .cubicInOut:
            if value < 0.5 { return 4 * value * value * value }
            let shifted = (2 * value) - 2
            return (shifted * shifted * shifted / 2) + 1
        case .bounceOut:
            return bounceOut(value)
        case .bounceIn:
            return 1 - bounceOut(1 - value)
        case .springIn:
            return value * value * ((2.70158 * value) - 1.70158)
        case .springOut:
            let shifted = value - 1
            return (shifted * shifted * ((2.70158 * shifted) + 1.70158)) + 1
        }
    }

    /// How steeply `curve` climbs at `progress`, per unit of progress: a central
    /// difference on the curve, a function of progress alone.
    static func slope(_ curve: Easing, at progress: Double) -> Double {
        let step = 1e-4
        let from = min(max(progress - step, 0), 1)
        let to = min(max(progress + step, 0), 1)
        guard to > from else { return 0 }
        return (ease(curve, at: to) - ease(curve, at: from)) / (to - from)
    }

    private static func bounceOut(_ value: Double) -> Double {
        if value < 1 / 2.75 {
            return 7.5625 * value * value
        }
        if value < 2 / 2.75 {
            let shifted = value - (1.5 / 2.75)
            return (7.5625 * shifted * shifted) + 0.75
        }
        if value < 2.5 / 2.75 {
            let shifted = value - (2.25 / 2.75)
            return (7.5625 * shifted * shifted) + 0.9375
        }

        let shifted = value - (2.625 / 2.75)
        return (7.5625 * shifted * shifted) + 0.984375
    }
}
