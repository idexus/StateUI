// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/views/transitions.md#a-transition

/// How a view comes and goes as the tree gains and drops it: the effect its entry comes from, and the one its exit
/// goes to. Both move under the view's own motion, else the application's.
///
///     if showsNote {
///         Note().transition(.symmetric(.opacity.combined(with: .translation(y: 12))))
///     }
public struct Transition: Equatable, Sendable {
    /// The effect the view enters from.
    public let enter: TransitionEffect

    /// The effect the view exits to.
    public let exit: TransitionEffect

    /// Whether the view enters as it first appears with what holds it, not only as it joins what already stands.
    let entersInitially: Bool

    /// A transition entering from one effect and exiting to another.
    ///
    /// - Parameters:
    ///   - enter: what the view comes from.
    ///   - exit: what the view goes to.
    public init(enter: TransitionEffect, exit: TransitionEffect) {
        self.init(enter: enter, exit: exit, entersInitially: false)
    }

    private init(enter: TransitionEffect, exit: TransitionEffect, entersInitially: Bool) {
        self.enter = enter
        self.exit = exit
        self.entersInitially = entersInitially
    }

    /// A transition entering from `effect` and exiting to it.
    ///
    /// - Parameter effect: the effect, both ways.
    /// - Returns: the transition.
    public static func symmetric(_ effect: TransitionEffect) -> Transition {
        Transition(enter: effect, exit: effect)
    }

    /// The same transition entering, or not, as the view first appears with what holds it - a page shown, a window
    /// opened. Unless said, a view enters only as it joins what already stands.
    ///
    /// - Parameter enabled: whether it enters then too.
    /// - Returns: the transition.
    public func initialAppearance(_ enabled: Bool) -> Transition {
        Transition(enter: enter, exit: exit, entersInitially: enabled)
    }
}

extension Transition: HostRepresentable {
    /// The entry's five numbers, the exit's five, and 1 where the view enters as it first appears.
    public var propValue: PropValue {
        .numbers(enter.host.numbers + exit.host.numbers + [entersInitially ? 1 : 0])
    }

    /// The transition back from its numbers, its effects' steps in one order; nil for anything else.
    /// - Parameter propValue: what crossed.
    public init?(propValue: PropValue) {
        guard case .numbers(let numbers) = propValue, numbers.count == 11,
              let enter = HostTransitionEffect(numbers: numbers[0..<5]),
              let exit = HostTransitionEffect(numbers: numbers[5..<10])
        else { return nil }

        self.init(enter: TransitionEffect(enter), exit: TransitionEffect(exit), entersInitially: numbers[10] == 1)
    }
}

extension Transition {
    /// The transition as a host draws it.
    @_spi(Host) public var host: (enter: HostTransitionEffect, exit: HostTransitionEffect, entersInitially: Bool) {
        (enter.host, exit.host, entersInitially)
    }
}
