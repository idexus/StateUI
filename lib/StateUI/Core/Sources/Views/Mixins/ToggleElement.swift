// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control turned on and off shares - a check box, a switch, a menu's and a toolbar's toggle: its
/// position, given in its initializer, and `onToggled`, what the user's turn does.
///
///     Switch("Wi-Fi", isOn: $wifi)
///         .onToggled { on in log("Wi-Fi \(on)") }
public protocol ToggleElement: PropertyContainer {}

extension ToggleElement where Modified == Self {
    /// What the user's turn does, handed the position it turned to; it runs after the state's write.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        modified { $0.addHandler(ToggleElementContract.toggled, handler) }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        modified { $0.addHandler(ToggleElementContract.toggled, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onToggled(gate: Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        modified { $0.addHandler(ToggleElementContract.toggled, gate: gate, handler) }
    }
}
