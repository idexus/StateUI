// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What brings an element's own presentation after its press, and back onto its place once the hand that held it
/// lets go: two bodies of the solver every layout's children move by - one behind what the press answers, one
/// behind the place the hand left - so a press with a spring of its own grows a view with no jump, and a view let
/// go comes back as a body does.
/// Design: docs/design/host/interaction.md#a-press-with-a-spring-of-its-own
struct LocalFollow: Sendable {
    private var bodies = LayoutBodies()

    /// What the press answered last: where what is shown is bound for.
    private(set) var target = PresentationOffset.identity

    private static let press = 0, back = 1

    /// Whether what is shown is still on its way.
    var moves: Bool { !bodies.isEmpty }

    /// The press answers `target`: on `spring`, what is shown comes after it from where it stands; on none, it is
    /// there at once.
    mutating func aim(at target: PresentationOffset, on spring: HostLayoutBody?, now: Double) {
        guard target != self.target else { return }

        if let spring {
            var moved = LayoutShift.none.lanes
            moved[LayoutShift.moveX] = self.target.translation.x - target.translation.x
            moved[LayoutShift.moveY] = self.target.translation.y - target.translation.y
            moved[LayoutShift.turn] = self.target.rotation - target.rotation
            moved[LayoutShift.scaleX] = self.target.scaleX - target.scaleX
            moved[LayoutShift.scaleY] = self.target.scaleY - target.scaleY
            bodies.carry(Self.press, by: moved, spring: spring, at: now)
        }
        self.target = target
    }

    /// The hand let go a view it held `held` from its place, going `velocity`: on `spring` the view comes back
    /// from there at the hand's speed; on none it is at its place at once.
    mutating func letGo(from held: Point, velocity: Point, on spring: HostLayoutBody?, now: Double) {
        guard let spring, held != .zero || velocity != .zero else { return }

        var (lanes, speed) = (LayoutShift.none.lanes, LayoutShift.none.lanes)
        (lanes[LayoutShift.moveX], lanes[LayoutShift.moveY]) = (held.x, held.y)
        (speed[LayoutShift.moveX], speed[LayoutShift.moveY]) = (velocity.x, velocity.y)
        bodies.set(Self.back, lanes: lanes, velocity: speed, spring: spring, at: now)
    }

    /// Nothing answers a press any longer, and nothing comes back: the view as its layout has it.
    mutating func stop() {
        self = LocalFollow()
    }

    /// Steps what is shown to `now`: the offset laid over the view.
    mutating func step(to now: Double) -> PresentationOffset {
        bodies.step(to: now)

        var shown = target
        for key in [Self.press, Self.back] {
            guard let lanes = bodies[key]?.lanes else { continue }

            shown.translation.x += lanes[LayoutShift.moveX]
            shown.translation.y += lanes[LayoutShift.moveY]
            shown.rotation += lanes[LayoutShift.turn]
            shown.scaleX += lanes[LayoutShift.scaleX]
            shown.scaleY += lanes[LayoutShift.scaleY]
        }
        return shown
    }
}
