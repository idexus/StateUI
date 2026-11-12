// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for the spring's `exp`, `sin` and `cos`.
import StateUIFoundation

// The motion laws as numbers, in closed form in the time since an animation
// began. Every runtime animates with these; `MotionLawTests` holds them to
// their promises.
// Design: docs/design/core/journeys.md#motion-laws

/// Where an animation stands at one instant of its law.
@_spi(Host) public struct HostMotionSample: Equatable, Sendable {
    /// The value of each lane.
    public let value: [Double]

    /// How fast each lane is going, per second.
    public let velocity: [Double]

    /// Whether the animation has arrived: every lane at its destination and still.
    public let rested: Bool
}

/// The motion laws, evaluated from the time since an animation began.
///
/// Time is in milliseconds, the unit of `Motion`'s numbers; a speed is per
/// second, as a journey's is, told in and answered.
@_spi(Host) public enum HostMotionLaw {
    /// How near its destination a lane is when it counts as arrived, in the value's
    /// own units. A thousandth of a color channel or of a point is below any
    /// display's resolution.
    public static let still = 0.001

    /// How slow a lane is when it counts as still, per second: a thousandth of a unit
    /// a millisecond.
    public static let stillSpeed = 1.0

    /// The shortest a glide takes, in milliseconds: a hand let go fast slows over no less.
    public static let shortestGlide = 80.0

    /// The longest a spring animates, in milliseconds. A spring has no stated end;
    /// this keeps any animation from holding a display clock awake for ever.
    public static let longest = 10_000.0

    /// Where an animation stands `elapsed` milliseconds after it began.
    ///
    /// An eased animation from a standstill follows its curve exactly. A lane that
    /// began moving follows its curve too, bent at its start to set out at the speed
    /// it had and landing where the curve does - an overshooting curve still
    /// overshoots. A spring settles each lane on its own, and the animation rests
    /// when all of them have.
    ///
    /// - Parameters:
    ///   - motion: The law and its numbers.
    ///   - elapsed: Milliseconds since the animation began.
    ///   - from: Where each lane began.
    ///   - destination: Where each lane is going.
    ///   - velocity: How fast each lane was going when it began, per second.
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

        // The arithmetic runs in milliseconds: a speed is told per second and answered so.
        let velocity = velocity.map { $0 / 1_000 }
        let sample: HostMotionSample
        switch motion.kind {
        case .eased(let milliseconds, let curve):
            sample = eased(
                length: Double(milliseconds),
                curve: curve,
                elapsed: elapsed,
                from: from,
                destination: destination,
                velocity: velocity)
        case .spring(let milliseconds, let damping):
            sample = spring(
                response: Double(max(milliseconds, 1)),
                damping: max(damping, 0.01),
                elapsed: elapsed,
                from: from,
                destination: destination,
                velocity: velocity)
        case .glide(let milliseconds):
            sample = glide(
                longest: Double(milliseconds), elapsed: elapsed, from: from, destination: destination,
                velocity: velocity)
        case .inherited, .none, .custom:
            sample = landed(destination)
        }
        // A sample that came out no number - arithmetic past what a double holds - lands, for every reader alike.
        guard (sample.value + sample.velocity).allSatisfy(\.isFinite) else { return landed(destination) }
        return HostMotionSample(
            value: sample.value, velocity: sample.velocity.map { $0 * 1_000 }, rested: sample.rested)
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

        // A lane already moving is the curve bent by p(1 - p)²: nothing at either end, its slope at the start the
        // difference between the speed it had and the curve's own.
        // Design: docs/design/core/journeys.md#motion-laws
        let rest = 1 - progress
        let bend = progress * rest * rest
        let bending = rest * (1 - 3 * progress)
        let setsOut = slope(curve, at: 0)

        var value = Array(repeating: 0.0, count: from.count)
        var speed = value

        for lane in value.indices {
            let span = destination[lane] - from[lane]
            let difference = velocity[lane] == 0 ? 0 : length * velocity[lane] - span * setsOut
            value[lane] = from[lane] + span * amount + difference * bend
            speed[lane] = (span * climb + difference * bending) / length
        }

        return HostMotionSample(value: value, velocity: speed, rested: false)
    }

    /// A glide: each lane on `cubicOut` over the length that sets it out at the speed it had, held to
    /// `shortestGlide` and `longest` - where held, bent to set out at that speed as an eased lane is; a lane setting
    /// out still, or away from its destination, over half of `longest`.
    /// Design: docs/design/types/motion.md#a-glide
    private static func glide(
        longest: Double, elapsed: Double, from: [Double], destination: [Double], velocity: [Double]
    ) -> HostMotionSample {
        let setsOut = slope(.cubicOut, at: 0)
        var value = Array(repeating: 0.0, count: from.count)
        var speed = value
        var rested = true

        for lane in value.indices {
            let span = destination[lane] - from[lane]
            let length = velocity[lane] * span > 0
                ? min(max(setsOut * abs(span / velocity[lane]), shortestGlide), longest) : longest / 2
            let one = eased(
                length: length, curve: .cubicOut, elapsed: elapsed, from: [from[lane]], destination: [destination[lane]],
                velocity: [velocity[lane]])
            value[lane] = one.value[0]
            speed[lane] = one.velocity[0]
            rested = rested && one.rested
        }

        return rested ? landed(destination) : HostMotionSample(value: value, velocity: speed, rested: false)
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

        var value = Array(repeating: 0.0, count: from.count)
        var speed = value
        var rested = true

        for lane in value.indices {
            let target = destination[lane]
            let (remaining, derivative) = spring(
                response: response, damping: damping, elapsed: elapsed, displacement: from[lane] - target,
                speed: velocity[lane])

            if abs(remaining) <= still && abs(derivative) * 1_000 <= stillSpeed {
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

    /// One lane of a spring `elapsed` milliseconds on, from `displacement` off its destination going `speed` a
    /// millisecond: how far off it stands and how fast it goes - in closed form for every damping, the one answer
    /// an animation and a motion layout's body both move by.
    static func spring(
        response: Double, damping: Double, elapsed: Double, displacement: Double, speed initialSpeed: Double
    ) -> (remaining: Double, derivative: Double) {
        let frequency = 2 * Double.pi / response
        if abs(damping - 1) < 1e-6 {
            let b = initialSpeed + (frequency * displacement)
            let decay = exp(-frequency * elapsed)
            return ((displacement + (b * elapsed)) * decay, (b - (frequency * (displacement + (b * elapsed)))) * decay)
        }
        if damping < 1 {
            let damped = frequency * sqrt(1 - (damping * damping))
            let a = displacement
            let b = (initialSpeed + (damping * frequency * displacement)) / damped
            let decay = exp(-damping * frequency * elapsed)
            let cosine = cos(damped * elapsed)
            let sine = sin(damped * elapsed)
            return (
                decay * ((a * cosine) + (b * sine)),
                decay * ((-damping * frequency * ((a * cosine) + (b * sine))) + (damped * ((b * cosine) - (a * sine)))))
        }
        // The two rates written so neither the damping's square nor their difference loses the number: the slow
        // one as the fast one's reciprocal, the constants over the fast one.
        let spread = damping * sqrt(1 - (1 / damping) / damping)
        let first = -frequency / (damping + spread)
        let second = -frequency * (damping + spread)
        let c1 = (displacement - (initialSpeed / second)) / (1 - (first / second))
        let c2 = displacement - c1
        return (
            (c1 * exp(first * elapsed)) + (c2 * exp(second * elapsed)),
            (c1 * first * exp(first * elapsed)) + (c2 * second * exp(second * elapsed)))
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
        case .backIn:
            return value * value * ((2.70158 * value) - 1.70158)
        case .backOut:
            let shifted = value - 1
            return (shifted * shifted * ((2.70158 * shifted) + 1.70158)) + 1
        }
    }

    /// How steeply `motion` sets out, per unit of its length: eased, its curve's first slope; a glide, `cubicOut`'s;
    /// a spring, as a `cubicOut` of its response does - never under a tenth, so a curve setting out flat reaches a
    /// finite way.
    static func setsOut(_ motion: Motion) -> Double {
        if case .eased(_, let curve) = motion.kind { return max(slope(curve, at: 0), 0.1) }
        return slope(.cubicOut, at: 0)
    }

    /// How far a value going at `speed` a second carries on under `motion` alone: its speed for the motion's length
    /// over how steeply the motion sets out; none under a motion that does not animate.
    /// Design: docs/design/types/motion.md#where-a-throw-reaches
    static func carried(_ speed: Double, under motion: Motion) -> Double {
        guard motion.animates else { return 0 }

        return speed * Double(motion.milliseconds) / 1_000 / setsOut(motion)
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
