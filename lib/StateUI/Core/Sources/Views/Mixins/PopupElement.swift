// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control whose choices open in a list of their own shares - a picker, a date's and a time's: whether the
/// list is showing, and what its opening and closing do.
///
///     DatePicker($due)
///         .isOpen($choosing)
///         .onClosed { save() }
public protocol PopupElement: ElementView {}

extension PopupElement {
    /// The user has opened its list of choices. Opening it with `isOpen(true)` raises
    /// nothing: the application already knows.
    public func onOpened(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PopupElementContract.opened, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onOpened(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PopupElementContract.opened, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onOpened(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PopupElementContract.opened, gate: gate, handler)
    }

    /// It has closed - by a choice, by a tap outside, or by the platform.
    public func onClosed(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PopupElementContract.closed, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onClosed(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PopupElementContract.closed, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClosed(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PopupElementContract.closed, gate: gate, handler)
    }

    /// Whether its list of choices is showing.
    ///
    /// Settable, so a button elsewhere on the page can open it - and the
    /// platform closes it by itself, which is what `onClosed` is for.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(PopupElementContract.isOpen, value)
    }

    /// `isOpen` from a state, `$x`, both ways: the host opens and closes its list of choices as the state stands, and
    /// the user's opening and closing come back into it; no view is rebuilt for it.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        opening(PopupElementContract.isOpen, by: state, opened: PopupElementContract.opened, closed: PopupElementContract.closed)
    }
}
