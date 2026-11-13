// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where an operation stands; the last four are terminal and never change.
public enum OperationState: String, Codable, Sendable {
    /// Accepted, not started.
    case queued
    /// At work.
    case running
    /// Asked to stop, cleaning up.
    case cancelling
    /// Done, its result standing.
    case succeeded
    /// Ended by a failure, its error standing.
    case failed
    /// Stopped as asked, its cleanup done.
    case cancelled
    /// Ended by the service ending.
    case interrupted

    /// Whether the state is the operation's last.
    public var isTerminal: Bool {
        switch self {
        case .queued, .running, .cancelling: false
        case .succeeded, .failed, .cancelled, .interrupted: true
        }
    }
}
