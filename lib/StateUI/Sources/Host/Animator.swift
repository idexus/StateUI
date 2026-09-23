// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an animation moves: a state's channel, a described property, or a layout's place.
@_spi(Host) public enum AnimationTarget: Hashable, Comparable {
    /// The channel of the state with this number.
    case state(Int32)

    /// A property a patch described, on one mounted element.
    case described(DescribedKey)

    /// The place a layout gave the mounted element with this key.
    case placed(UInt64)

    /// States first, then described properties, then places; each in key order.
    public static func < (left: Self, right: Self) -> Bool {
        switch (left, right) {
        case (.state(let a), .state(let b)): return a < b
        case (.described(let a), .described(let b)): return a < b
        case (.placed(let a), .placed(let b)): return a < b
        default: return left.rank < right.rank
        }
    }

    private var rank: Int {
        switch self {
        case .state: return 0
        case .described: return 1
        case .placed: return 2
        }
    }
}

/// One running animation of a value, pure in the time handed to it.
/// Design: docs/design/host/motion.md#one-animator
@_spi(Host) public struct Animation: Equatable {
    /// Where each lane began.
    public let from: [Double]

    /// Where each lane is going.
    public let destination: [Double]

    /// Each lane's speed when it began, per millisecond.
    public let velocity: [Double]

    /// The timing it runs under.
    public let motion: Motion

    /// When it began, in the frame clock's milliseconds.
    public let began: Double

    /// A animation from `from` to `destination`, begun at `began`.
    public init(from: [Double], destination: [Double], velocity: [Double], motion: Motion, began: Double) {
        self.from = from
        self.destination = destination
        self.velocity = velocity
        self.motion = motion
        self.began = began
    }

    /// Each lane's value and speed at `now`, and whether it has arrived.
    public func position(at now: Double) -> (value: [Double], velocity: [Double], rested: Bool) {
        let sample = HostMotionLaw.sample(
            motion, elapsed: max(0, now - began), from: from, destination: destination, velocity: velocity)
        return (sample.value, sample.velocity, sample.rested)
    }

    /// Whether it starts where it ends, standing still: nothing to animate.
    public var arrives: Bool {
        zip(from, destination).allSatisfy { abs($0 - $1) < HostMotionLaw.still }
            && velocity.allSatisfy { abs($0) < HostMotionLaw.still }
    }
}

/// Where one animation stands after the animator advances.
@_spi(Host) public struct AnimationStep {
    /// What the animation moves.
    public let target: AnimationTarget

    /// Each lane's value.
    public let value: [Double]

    /// Each lane's speed, per millisecond.
    public let velocity: [Double]

    /// Whether the animation arrived; an arrived animation has left the animator.
    public let rested: Bool
}

/// The runtime's one animator: every animation, advanced together in target order.
/// Design: docs/design/host/motion.md#one-animator
@_spi(Host) @MainActor public final class Animator {
    private var animations: [AnimationTarget: Animation] = [:]

    /// A animator with no animation under way.
    public init() {}

    /// Whether any animation is under way.
    public var isMoving: Bool { !animations.isEmpty }

    /// The animation under way for `target`.
    public func animation(for target: AnimationTarget) -> Animation? { animations[target] }

    /// Starts `animation` for `target`, in place of any animation it had.
    public func start(_ animation: Animation, for target: AnimationTarget) { animations[target] = animation }

    /// Ends `target`'s animation where it stands.
    public func halt(_ target: AnimationTarget) { animations[target] = nil }

    /// Advances every animation to `now` in target order; with less motion, each one arrives.
    public func advance(to now: Double, reducesMotion: Bool = false) -> [AnimationStep] {
        var steps: [AnimationStep] = []

        for target in animations.keys.sorted() {
            guard let animation = animations[target] else { continue }

            let position = reducesMotion
                ? (animation.destination, Array(repeating: 0, count: animation.destination.count), true)
                : animation.position(at: now)

            if position.2 { animations[target] = nil }
            steps.append(AnimationStep(target: target, value: position.0, velocity: position.1, rested: position.2))
        }

        return steps
    }

    /// Keeps only the animations whose target `keep` still has.
    public func retain(where keep: (AnimationTarget) -> Bool) {
        animations = animations.filter { keep($0.key) }
    }
}
