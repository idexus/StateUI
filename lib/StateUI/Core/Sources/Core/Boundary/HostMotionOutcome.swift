// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How the host says a channel's run ended - what answers the movement's waiter.
/// Design: docs/design/core/journeys.md#a-movements-result
@_spi(Host) public enum HostMotionOutcome: Equatable, Sendable {
    /// The lanes stand at the destination, having traveled there.
    case animated

    /// The lanes were put at the destination at once, for the reason given.
    case immediate(MotionImmediateReason)

    /// A newer destination, a written value or the user's hand took the lanes.
    case superseded

    /// A stop ended it.
    case stopped

    /// The channel's last receiver left.
    case detached

    /// What a waiter is answered.
    var result: MotionResult {
        switch self {
        case .animated: .reached(.animated)
        case .immediate(let reason): .reached(.immediate(reason))
        case .superseded: .superseded
        case .stopped: .stopped
        case .detached: .detached
        }
    }
}
