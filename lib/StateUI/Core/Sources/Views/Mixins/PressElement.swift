// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control held down and let go of shares - a button, a slider: what a press beginning and ending do.
///
///     Button("Record")
///         .onPressed { recorder.start() }
///         .onReleased { recorder.stop() }
public protocol PressElement: ModifiableElement {}

extension PressElement {
    /// Runs the moment a press begins, before it ends.
    public func onPressed(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PressElementContract.pressed, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPressed(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PressElementContract.pressed, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPressed(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PressElementContract.pressed, gate: gate, handler)
    }

    /// Runs when the press ends, wherever the pointer ends up - unlike
    /// `onClicked`, which needs it to end on the button.
    public func onReleased(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PressElementContract.released, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onReleased(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PressElementContract.released, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onReleased(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PressElementContract.released, gate: gate, handler)
    }
}
