// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a program ended, and whether this tool stopped it.
public struct ProcessOutcome: Sendable, Equatable {
    /// How a program ended.
    public enum Termination: Sendable, Equatable {
        /// The program exited with a status.
        case exited(Int)
        /// A signal ended the program.
        case signaled(Int)
    }

    /// Why this tool stopped a program.
    public enum Stop: Sendable, Equatable {
        /// The program ran past its time limit.
        case timeout
        /// The task running it was cancelled.
        case cancellation
    }

    /// How the program ended.
    public var termination: Termination
    /// Why this tool stopped the program; `nil` when it ended by itself.
    public var stop: Stop?

    /// A program that ended by `termination`, stopped for `stop`.
    public init(termination: Termination, stop: Stop? = nil) {
        self.termination = termination
        self.stop = stop
    }

    /// Whether the program ended by itself with status 0.
    public var succeeded: Bool { termination == .exited(0) && stop == nil }
}
