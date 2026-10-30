// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a phase layout's views move by between where its arithmetic puts them and where they are shown: each view a
/// body on a spring to its place.
///
///     PhaseLayout(cards, id: \.name) { CardFace($0) } placements: { room, phase in … }
///         .physicsWorld(.spring(response: .milliseconds(420), damping: 0.8))
///
/// A view whose place a change moves - a card joining, the run arranged anew - sets out from where it was shown
/// and comes onto its place on the world's spring; a body of its own (`.physicsBody(_:)`) says otherwise. The world
/// is worked out at a fixed step, so every host and every frame rate shows the same motion; under less motion every
/// view lands on its place at once.
/// Design: docs/design/views/phase-layout.md#bodies
public struct PhysicsWorld: Equatable, Sendable {
    /// The spring every body comes onto its place on, unless its own says another; nil for a world whose views land
    /// at once.
    let spring: LayoutBodies.Spring?

    /// Bodies coming onto their places without passing them, in 300 milliseconds: what a layout says nothing of.
    public static let standard = PhysicsWorld.spring()

    /// No motion: every view stands at its place at once.
    public static let none = PhysicsWorld(spring: nil)

    /// Bodies on a spring of `response`, damped by `damping` - 1 coming onto the place without passing it, below 1
    /// passing it and coming back.
    ///
    /// - Parameters:
    ///   - response: how quickly a body answers, to the millisecond. Smaller is snappier.
    ///   - damping: how much it is held back; a damping that is no number is 1.
    /// - Returns: the world.
    public static func spring(response: Duration = .milliseconds(300), damping: Double = 1) -> PhysicsWorld {
        PhysicsWorld(spring: LayoutBodies.Spring(
            response: Double(Motion.milliseconds(of: response)), damping: damping.isFinite ? max(damping, 0.01) : 1))
    }
}
