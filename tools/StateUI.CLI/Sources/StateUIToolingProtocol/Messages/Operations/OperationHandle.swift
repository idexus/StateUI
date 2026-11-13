// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An accepted operation, as a mutating method answers: its id and where it stands.
public struct OperationHandle: Codable, Equatable, Sendable {
    /// The operation's opaque id.
    public var operationId: String
    /// Where it stands.
    public var state: OperationState

    /// The operation `operationId`, standing at `state`.
    public init(operationId: String, state: OperationState) {
        self.operationId = operationId
        self.state = state
    }
}
