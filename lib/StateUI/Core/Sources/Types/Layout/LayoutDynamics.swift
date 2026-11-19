// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a motion layout's views move by between where its arithmetic puts them and where they are shown: each view a
/// body on a spring to its place.
///
///     MotionLayout(cards, id: \.name, parameters: $turn) { CardFace($0) } placements: { context, turn in … }
///         .dynamics(.spring(Spring(response: .milliseconds(420), damping: 0.8)))
///
/// A view whose place a change moves - a card joining, the run arranged anew - sets out from where it was shown
/// and comes onto its place on the world's spring; a body of its own (`.layoutBody(_:)`) says otherwise. The world
/// is worked out at a fixed step, so every host and every frame rate shows the same motion; under less motion every
/// view lands on its place at once.
/// Design: docs/design/views/motion-layout.md#bodies
public struct LayoutDynamics: Equatable, Sendable {
    /// The spring every body comes onto its place on, unless its own says another; nil for a world whose views land
    /// at once.
    let spring: Spring?

    /// Bodies coming onto their places without passing them, in 300 milliseconds: what a layout says nothing of.
    public static let standard = LayoutDynamics.spring()

    /// No motion: every view stands at its place at once.
    public static let none = LayoutDynamics(spring: nil)

    /// Bodies on `spring` - a damping of 1 coming onto the place without passing it, below 1 passing it and coming
    /// back.
    ///
    /// - Parameter spring: how quickly a body answers and how it is damped; the standard spring where none is named.
    /// - Returns: the world.
    public static func spring(_ spring: Spring = .standard) -> LayoutDynamics {
        LayoutDynamics(spring: spring)
    }
}
