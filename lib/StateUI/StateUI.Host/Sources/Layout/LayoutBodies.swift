// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The bodies of one layout: how far each child stands from where its layout puts it, lane by lane as a shift's
/// (`LayoutShift`), and how fast each lane goes - each body a mass on a spring to its place, worked out at a fixed
/// step, so the same frames or other ones bring it to the same place, and landed there by the longest a spring
/// animates.
/// Design: docs/design/host/layout.md#bodies
struct LayoutBodies: Equatable, Sendable {
    /// One body: its shift's lanes, how fast each goes, per second, the spring that pulls it onto its place, and
    /// how long it has moved since it was last set or carried, in milliseconds.
    struct Body: Equatable, Sendable {
        var lanes: [Double]
        var velocity: [Double]
        var spring: HostLayoutBody
        var moved = 0.0
    }

    /// The bodies, by the identity of the view each is.
    private(set) var bodies: [Int: Body] = [:]

    /// When the world was last worked out to, and the time since that no step took yet, in milliseconds.
    private var stepped: Double?
    private var owed = 0.0

    /// How long one step is, in milliseconds, and the most steps one frame works out: a world behind by more lets
    /// the rest go, slowing rather than spending a frame catching up.
    static let step = 1_000.0 / 240
    static let mostSteps = 32

    /// Whether no body is in the world.
    var isEmpty: Bool { bodies.isEmpty }

    /// The body of the view `identity`; nil where it is at its place.
    subscript(identity: Int) -> Body? { bodies[identity] }

    /// Puts the view `identity` in the world at `lanes` from its place, going `velocity`, on `spring`, at `now` - the
    /// world's clock starting there where it held no body.
    mutating func set(_ identity: Int, lanes: [Double], velocity: [Double], spring: HostLayoutBody, at now: Double) {
        if bodies.isEmpty { (stepped, owed) = (now, 0) }
        bodies[identity] = Body(lanes: lanes, velocity: velocity, spring: spring)
    }

    /// Carries the view `identity` by `moved` - its place having moved the other way under it - a body on `spring`
    /// made for it where it had none.
    mutating func carry(_ identity: Int, by moved: [Double], spring: HostLayoutBody, at now: Double) {
        guard moved.contains(where: { $0 != 0 }) else { return }

        guard var body = bodies[identity] else {
            return set(identity, lanes: moved, velocity: Array(repeating: 0, count: moved.count), spring: spring, at: now)
        }
        for lane in body.lanes.indices where lane < moved.count { body.lanes[lane] += moved[lane] }
        body.moved = 0
        bodies[identity] = body
    }

    /// Keeps the bodies of `identities` alone: a view leaving the run leaves the world.
    mutating func keep(only identities: Set<Int>) {
        bodies = bodies.filter { identities.contains($0.key) }
    }

    /// Works the world out to `now`: as many steps as the time since covers, no more than `mostSteps`; a body at
    /// rest on its place leaves it.
    mutating func step(to now: Double) {
        guard let last = stepped else { return stepped = now }

        owed += max(now - last, 0)
        stepped = now
        var steps = Int(owed / Self.step)
        owed -= Double(steps) * Self.step
        if steps > Self.mostSteps { (steps, owed) = (Self.mostSteps, 0) }
        guard steps > 0 else { return }

        for (identity, var body) in bodies {
            for _ in 0..<steps { body.advance(by: Self.step) }
            bodies[identity] = body.rests ? nil : body
        }
    }
}

extension LayoutBodies.Body {
    /// The body `milliseconds` on, its spring pulling each lane onto nought: the motion law's own closed form, so a
    /// step of any spring is where the spring is then, never a step past it. A body moving the longest a spring
    /// animates, or come out no number, lands on its place.
    mutating func advance(by milliseconds: Double) {
        moved += milliseconds
        for lane in lanes.indices {
            let (place, speed) = HostMotionLaw.spring(
                response: max(spring.milliseconds, 1), damping: max(spring.damping, 0.01), elapsed: milliseconds,
                displacement: lanes[lane], speed: velocity[lane] / 1_000)
            let perSecond = speed * 1_000
            let lands = moved >= HostMotionLaw.longest || !place.isFinite || !perSecond.isFinite
            (lanes[lane], velocity[lane]) = lands ? (0, 0) : (place, perSecond)
        }
    }

    /// Whether the body is at rest on its place: every lane as near and as slow as an animation counts arrived.
    var rests: Bool {
        lanes.allSatisfy { abs($0) <= HostMotionLaw.still } && velocity.allSatisfy { abs($0) <= HostMotionLaw.stillSpeed }
    }
}
