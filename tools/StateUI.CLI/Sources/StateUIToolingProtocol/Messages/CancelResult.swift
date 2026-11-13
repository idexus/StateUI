// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The answer to `operation/cancel`.
public struct CancelResult: Codable, Equatable, Sendable {
    /// Whether the operation is stopping or stopped by this or an earlier cancel; `false` once it ended otherwise.
    public var accepted: Bool
    /// Where the operation stands.
    public var state: OperationState

    /// A cancel `accepted` or not, the operation standing at `state`.
    public init(accepted: Bool, state: OperationState) {
        self.accepted = accepted
        self.state = state
    }
}
