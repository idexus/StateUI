// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Task where Success == Void, Failure == Never {
    /// Starts `operation` through `gate` as a handler written with it runs: the gate's policy holds for it, it
    /// makes the gate busy, and cancelling the task supersedes the run - or, while it waits its turn, takes it out
    /// of the queue. A task the gate lets go ends at once, its work not run.
    ///
    ///     func autosave() { Task(gate: document) { try await model.save() } }
    ///
    /// The run belongs to the gate: no element leaving, nor the handler that started it, ends it.
    /// Design: docs/design/core/runs.md#work-started-from-code
    @MainActor @discardableResult
    public init(gate: SharedGate, operation: @escaping EventHandler) {
        self = gate.runs.start(operation, gate.policy, payload: nil, owner: gate.tasks)
    }
}
