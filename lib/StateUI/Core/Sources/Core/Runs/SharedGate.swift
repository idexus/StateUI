// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A gate kept in a state or a model, shared by every handler and task written with it - from one control, several,
/// or code - which says whether a run is under way through it.
///
///     @State private var document = SharedGate(.ignoreWhileRunning)
///
///     Button("Save").isEnabled(!document.isBusy).onClicked(gate: document) { try await model.save() }
///     Button("Delete").isEnabled(!document.isBusy).onClicked(gate: document) { try await model.delete() }
///
///     func autosave() { Task(gate: document) { try await model.save() } }
///
/// An element leaving ends its own runs alone: the others' through the gate go on.
/// Design: docs/design/core/runs.md#a-gate
@MainActor
public final class SharedGate: Gate {
    /// What an event or a task does while a run is under way through the gate.
    public nonisolated let policy: GatePolicy

    /// Whether a run is under way through the gate, or waits to start: a state, read to dim a control or show
    /// progress while the work goes on.
    @State public private(set) var isBusy = false

    /// A gate of `policy`, shared by every handler and task written with it.
    public init(_ policy: GatePolicy) {
        self.policy = policy
        runs.busyChanged = { [weak self] busy in
            HandlerRun.$current.withValue(nil) { self?.isBusy = busy }
        }
    }

    /// The runs under way through the gate.
    let runs = RunSlot()

    /// Who starts the runs of tasks written with the gate: no element, so no element leaving ends them.
    let tasks = RunOwner()
}
