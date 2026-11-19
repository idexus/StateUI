// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A spring: how quickly it answers, and how it is damped. Every spring StateUI runs is one - a motion's, a layout
/// body's.
///
///     .motion(.spring(Spring(response: .milliseconds(260), damping: 0.8)))
///
/// A spring has no duration: it settles when it is done, and one whose destination changes on the way carries on
/// from the speed it had.
/// Design: docs/design/types/motion.md#spring-numbers
public struct Spring: Equatable, Sendable {
    /// How quickly it answers, in milliseconds: at least one.
    @_spi(Host) public let milliseconds: UInt32

    /// How it is damped: 1 comes to rest without passing, below 1 passes and comes back; at least 0.05.
    @_spi(Host) public let damping: Double

    /// A spring answering in `response`, damped by `damping`.
    ///
    /// - Parameters:
    ///   - response: how quickly it answers, to the millisecond and at least one. Smaller is snappier.
    ///   - damping: 1 comes to rest without overshooting; below 1 overshoots and oscillates, which is rarely what
    ///     a user expects. At least 0.05; a damping that is no number is 1.
    public init(response: Duration = .milliseconds(300), damping: Double = 1) {
        milliseconds = max(Motion.milliseconds(of: response), 1)
        self.damping = damping.isFinite ? max(damping, 0.05) : 1
    }

    /// The spring where none is named: 300 milliseconds, damped to rest without passing.
    public static let standard = Spring()

    /// A spring back from the numbers it crossed as: its response in milliseconds, and its damping.
    init(milliseconds: Double, damping: Double) {
        self.init(response: .milliseconds(milliseconds.isFinite ? Int64(max(milliseconds, 0).rounded()) : 300), damping: damping)
    }

    /// Its response, in milliseconds, as arithmetic reads it.
    var response: Double { Double(milliseconds) }
}
