// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The parameters naming one operation: `operation/get`'s and `operation/cancel`'s.
public struct OperationReference: Codable, Equatable, Sendable {
    /// The operation's id.
    public var operationId: String

    /// The operation `operationId`.
    public init(operationId: String) {
        self.operationId = operationId
    }
}
