// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a view of a motion layout comes onto the place its layout gives it: at once, on a spring when the layout
/// changes, or on a spring behind a place that keeps moving.
///
///     MotionLayout(cards, id: \.name, parameters: $turn) { card in
///         CardFace(card).layoutBody(.followsLayout(response: .milliseconds(420), damping: 0.6))
///     } placements: { context, turn in … }
///     .layoutBodies(.onChange(response: .milliseconds(300), damping: 0.8))
///
/// `layoutBodies(_:)` says it for every view of a layout, `layoutBody(_:)` for one, which wins.
/// Design: docs/design/views/motion-layout.md#bodies
public struct LayoutBody: Equatable, Sendable {
    /// What a body answers.
    enum Kind: Equatable, Sendable {
        case none
        case onChange(Spring)
        case followsLayout(Spring)
    }

    let kind: Kind

    /// The spring the body comes onto its place on; nil for one that stands there at once.
    var spring: Spring? {
        switch kind {
        case .none: nil
        case .onChange(let spring), .followsLayout(let spring): spring
        }
    }

    /// Whether the body lags behind a place that moves under it.
    var follows: Bool {
        if case .followsLayout = kind { true } else { false }
    }

    /// The body as a host runs it; nil for none.
    @_spi(Host) public var host: HostLayoutBody? {
        spring.map { HostLayoutBody(milliseconds: $0.response, damping: $0.damping, follows: follows) }
    }

    /// No body: the view stands at its place at once, however the layout changes. The layout's parameters still
    /// travel as their state says.
    public static let none = LayoutBody(kind: .none)

    /// A body answering a change of the layout - a view joining, a new order, a new arrangement, a view the hand
    /// lets go: it comes onto its new place on a spring. A place moved by the parameters carries it with no lag.
    ///
    /// - Parameters:
    ///   - response: how quickly the spring answers, to the millisecond and at least one.
    ///   - damping: 1 comes to rest without overshooting, below 1 overshoots and comes back; at least 0.05.
    /// - Returns: the body.
    public static func onChange(response: Duration = .milliseconds(300), damping: Double = 1) -> LayoutBody {
        LayoutBody(kind: .onChange(Spring(response: response, damping: damping)))
    }

    /// A body following its place on a spring: it answers a change as `onChange(response:damping:)` does, and lags
    /// behind its place while the run moves too - a card swaying as the run scrolls, flying a little past where a
    /// throw stops at the end - and settles back onto it.
    ///
    /// - Parameters:
    ///   - response: how quickly the spring answers, to the millisecond and at least one.
    ///   - damping: 1 comes to rest without overshooting, below 1 overshoots and comes back; at least 0.05.
    /// - Returns: the body.
    public static func followsLayout(response: Duration = .milliseconds(300), damping: Double = 1) -> LayoutBody {
        LayoutBody(kind: .followsLayout(Spring(response: response, damping: damping)))
    }
}

extension LayoutBody: HostRepresentable {
    /// Which body it is - 0 none, 1 answering a change, 2 following its place - then its spring's response, in
    /// milliseconds, and damping.
    public var propValue: PropValue {
        switch kind {
        case .none: .numbers([0])
        case .onChange(let spring): .numbers([1, spring.response, spring.damping])
        case .followsLayout(let spring): .numbers([2, spring.response, spring.damping])
        }
    }

    /// The body back from its numbers, or nil for anything else.
    /// - Parameter propValue: what crossed.
    public init?(propValue: PropValue) {
        guard case .numbers(let numbers) = propValue, let which = numbers.first else { return nil }

        switch (which, numbers.count) {
        case (0, 1): kind = .none
        case (1, 3): kind = .onChange(Spring(milliseconds: numbers[1], damping: numbers[2]))
        case (2, 3): kind = .followsLayout(Spring(milliseconds: numbers[1], damping: numbers[2]))
        default: return nil
        }
    }
}
