// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a toolbar button and a menu entry that act share: `onClicked`, what
/// choosing one does, from `ClickElement`, and `role`, how the platform marks it.
///
///     MenuItem("Delete")
///         .role(.destructive)
///         .onClicked { delete() }
public protocol ActionElement: AutomationElement, ClickElement {}

extension ActionElement {
    /// What choosing it does beyond its words: `.destructive` is drawn as an
    /// action that destroys something, as a button's role is. The look only: a
    /// confirmation is still the handler's to put up.
    public func role(_ role: ActionRole) -> Modified {
        setValue(ActionElementContract.role, role)
    }
}

