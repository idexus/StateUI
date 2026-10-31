// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How one view of a motion layout moves as a body of its layout's world (`LayoutDynamics`).
///
///     MotionLayout(cards, id: \.name) { card in
///         CardFace(card).layoutBody(.followsLayout(.spring(response: .milliseconds(420), damping: 0.6)))
///     } placements: { room, parameters in … }
///
/// Design: docs/design/views/motion-layout.md#bodies
public struct LayoutBody: Equatable, Sendable {
    /// The spring it follows its place on.
    let spring: LayoutBodies.Spring

    /// A body following its place on `spring`: carried by the layout, it lags behind its place while the run moves
    /// - a card swaying as the run scrolls, flying a little past where a throw stops at the end - and settles back
    /// onto it. A spring's response and damping say how; any other motion stands for the world's standard spring.
    ///
    /// - Parameter spring: the spring, `.spring(response:damping:)`.
    /// - Returns: the body.
    public static func followsLayout(_ spring: Motion) -> LayoutBody {
        guard case .spring(let milliseconds, let damping) = spring.kind else {
            complain("A body follows its layout on a spring: .followsLayout(.spring(response:damping:)). "
                + "It follows on the world's standard spring.")
            return LayoutBody(spring: LayoutDynamics.standard.spring ?? LayoutBodies.Spring(response: 300, damping: 1))
        }
        return LayoutBody(spring: LayoutBodies.Spring(response: Double(milliseconds), damping: damping))
    }
}

extension LayoutBody: HostRepresentable {
    /// Its spring's response, in milliseconds, and damping.
    public var propValue: PropValue { .numbers([spring.response, spring.damping]) }

    /// The body back from its spring's numbers, or nil for anything else.
    /// - Parameter propValue: what crossed.
    public init?(propValue: PropValue) {
        guard case .numbers(let numbers) = propValue, numbers.count == 2 else { return nil }

        spring = LayoutBodies.Spring(response: numbers[0], damping: numbers[1])
    }
}
