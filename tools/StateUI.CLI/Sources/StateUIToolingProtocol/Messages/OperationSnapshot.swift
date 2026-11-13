// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An operation whole, as `operation/get` answers: what it is, where it stands, what it came to.
public struct OperationSnapshot: Codable, Equatable, Sendable {
    /// The operation's opaque id.
    public var id: String
    /// The method that started it.
    public var kind: String
    /// The client's token for the request.
    public var requestToken: String
    /// Where it stands.
    public var state: OperationState
    /// When it was accepted, in RFC 3339 UTC.
    public var createdAt: String
    /// When it started.
    public var startedAt: String?
    /// When it ended.
    public var finishedAt: String?
    /// The sequence of its last event; 0 before any.
    public var lastSequence: Int
    /// Its last progress.
    public var progress: OperationProgress?
    /// The method's result, once it succeeded.
    public var result: JSONValue?
    /// Why it failed.
    public var failure: ToolingError?

    /// A snapshot of an operation just accepted.
    public init(id: String, kind: String, requestToken: String, createdAt: String) {
        self.id = id
        self.kind = kind
        self.requestToken = requestToken
        self.state = .queued
        self.createdAt = createdAt
        self.lastSequence = 0
    }

    /// The operation's handle.
    public var handle: OperationHandle { OperationHandle(operationId: id, state: state) }
}
