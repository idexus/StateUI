// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control the user chooses shares - a button, a link, a menu's entry, a toolbar's button: `onClicked`, what
/// choosing it does.
///
///     Button("Save").onClicked { save() }
public protocol ClickElement: PropertyContainer {}

extension ClickElement where Modified == Self {
    /// What choosing it does - run when it is clicked, tapped, or chosen by the keyboard. A second `.onClicked` runs
    /// beside the first, like every typed event modifier.
    public func onClicked(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        modified { $0.addHandler(ClickElementContract.clicked.token, handler) }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onClicked(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(ClickElementContract.clicked.token, gate: .own(policy), handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClicked(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(ClickElementContract.clicked.token, gate: .shared(gate), handler) }
    }
}
