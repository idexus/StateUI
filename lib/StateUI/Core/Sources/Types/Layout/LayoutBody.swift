// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How one view of a motion layout moves as a body of its layout's world (`LayoutDynamics`).
///
///     MotionLayout(cards, id: \.name, parameters: $turn) { card in
///         CardFace(card).layoutBody(.followsLayout(Spring(response: .milliseconds(420), damping: 0.6)))
///     } placements: { context, turn in … }
///
/// Design: docs/design/views/motion-layout.md#bodies
public struct LayoutBody: Equatable, Sendable {
    /// The spring it follows its place on.
    let spring: Spring

    /// A body following its place on `spring`: carried by the layout, it lags behind its place while the run
    /// moves - a card swaying as the run scrolls, flying a little past where a throw stops at the end - and settles
    /// back onto it.
    ///
    /// - Parameter spring: how quickly the body answers and how it is damped; the standard spring where none is
    ///   named.
    /// - Returns: the body.
    public static func followsLayout(_ spring: Spring = .standard) -> LayoutBody {
        LayoutBody(spring: spring)
    }
}

extension LayoutBody: HostRepresentable {
    /// Its spring's response, in milliseconds, and damping.
    public var propValue: PropValue { .numbers([spring.response, spring.damping]) }

    /// The body back from its spring's numbers, or nil for anything else.
    /// - Parameter propValue: what crossed.
    public init?(propValue: PropValue) {
        guard case .numbers(let numbers) = propValue, numbers.count == 2 else { return nil }

        spring = Spring(milliseconds: numbers[0], damping: numbers[1])
    }
}
