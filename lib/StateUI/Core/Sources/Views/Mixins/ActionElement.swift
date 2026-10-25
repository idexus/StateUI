// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a toolbar button and a menu entry that act share: `onClicked`, what
/// choosing one does, and `role`, how the platform marks it.
///
///     MenuItem("Delete")
///         .role(.destructive)
///         .onClicked { delete() }
public protocol ActionElement: AutomationElement {}

extension ActionElement {
    /// What choosing it does beyond its words: `.destructive` is drawn as an
    /// action that destroys something, as a button's role is. The look only: a
    /// confirmation is still the handler's to put up.
    public func role(_ role: ActionRole) -> Modified {
        setValue(ActionElementContract.role, role)
    }
}

extension ActionElement where Modified == Self {
    /// What it does - run when the item is chosen, clicked or tapped. A second
    /// `.onClicked` runs beside the first, like every typed event modifier.
    public func onClicked(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        modified { $0.addHandler(ActionElementContract.clicked.token, handler) }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onClicked(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(ActionElementContract.clicked.token, gate: .own(policy), handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClicked(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(ActionElementContract.clicked.token, gate: .shared(gate), handler) }
    }
}
