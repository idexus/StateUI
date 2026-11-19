// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a movement ended - what `MotionRun.result()` answers, once.
///
///     switch try await $fade.journey.move(to: 0).result() {
///     case .reached: remove()
///     case .superseded, .stopped, .detached, .notStarted: break
///     }
///
/// Design: docs/design/core/journeys.md#a-movements-result
public enum MotionResult: Equatable, Sendable {
    /// The value stands at the destination it was sent to.
    case reached(MotionArrival)

    /// Something newer took the value over: another destination, a snap, the
    /// user's hand.
    case superseded

    /// `stop()` ended it where it stood.
    case stopped

    /// Nothing shows the state any more: its last receiver left.
    case detached

    /// No movement was made.
    case notStarted(MotionRefusal)
}

/// How a movement reached its destination.
public enum MotionArrival: Equatable, Sendable {
    /// It traveled there.
    case animated

    /// It was put there at once.
    case immediate(MotionImmediateReason)
}

/// Why a movement was put at its destination at once.
public enum MotionImmediateReason: Equatable, Sendable {
    /// The value stood there already.
    case alreadyAtDestination

    /// Its motion does not animate - `.none`.
    case motionDisabled

    /// The user asks for less motion.
    case reducedMotion
}

/// Why no movement was made.
public enum MotionRefusal: Equatable, Sendable {
    /// Nothing shows the state: the destination is written, and nothing moves.
    case noReceiver

    /// The state refuses the destination; nothing is written.
    case invalidDestination

    /// The host carries the state as the value itself, which nothing animates.
    case unsupportedValue

    /// An engine of the application animates the state and none is registered:
    /// the destination is written and shown at once.
    case noAnimator

    /// An engine of the application animates the state, which takes no motion;
    /// nothing is written.
    case incompatibleAnimator

    /// Whoever asked no longer runs: its handler was superseded.
    case inactiveOwner

    /// The state is derived with no way back; nothing is written.
    case readOnlyDerived
}
