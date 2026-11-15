// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an operation's work tells its client while it runs. Cancelling the operation cancels the work's task.
public struct OperationContext: Sendable {
    /// The operation's id.
    public let operationId: String
    let operations: Operations

    /// Tells how far the work has come.
    public func progress(_ progress: OperationProgress) async {
        await operations.progress(operationId, progress)
    }

    /// Tells that a run started its application.
    public func started(_ application: LaunchedApplication) async {
        await operations.started(operationId, application)
    }

    /// Passes on what a program wrote on `stream`.
    public func output(_ bytes: [UInt8], on stream: StandardStream) async {
        await operations.output(operationId, bytes, on: stream)
    }
}
