// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard: what
/// an aim's `focus()` reaches and a style's `.focused` state follows.
public protocol FocusElement: KeyboardElement {}

extension FocusElement {
    /// Whether the platform has given this control the focus, written into the
    /// binding. Read-only: the platform moves the focus.
    public func isFocused(_ state: Binding<Bool>) -> Modified {
        onEvent(FocusElementContract.isFocusedChanged) { focused in
            state.wrappedValue = focused
        }
    }
}
