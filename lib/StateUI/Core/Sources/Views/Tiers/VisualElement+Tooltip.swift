// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The words a view shows while the pointer rests on it.
// Design: docs/design/views/modifiers.md#a-tooltip

extension VisualElementProperties {
    /// Words the platform shows beside this view while the pointer rests on
    /// it, saying what the view does.
    ///
    ///     Button(icon: "bin.png")
    ///         .accessibilityLabel("Delete")
    ///         .tooltip("Moves the file to the bin")
    ///
    /// Each platform shows them its own way - while the pointer rests, or
    /// after a long press where the platform offers that; an iPhone shows none.
    public func tooltip(_ text: String) -> Modified { setValue(VisualElementContract.tooltip, text) }

    /// `tooltip` from a state, `$x`: the host writes each new text, and no
    /// view is rebuilt for it.
    public func tooltip(_ state: Binding<String>) -> Modified {
        words(VisualElementContract.tooltip, by: state)
    }
}
