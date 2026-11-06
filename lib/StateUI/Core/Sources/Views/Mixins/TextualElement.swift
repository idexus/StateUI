// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control whose text is a property: everything `TextColorElement` has,
/// plus the text itself.
public protocol TextualElement: TextColorElement {}

extension TextualElement {
    /// Whether the letters are drawn as written or in one case throughout.
    ///
    ///     Text("total").textCase(.uppercase)
    public func textCase(_ value: TextCase) -> Modified {
        setValue(TextualElementContract.textCase, value)
    }
}

extension TextualElement where Self: VisualElement {
    /// What the control says. Usually given in the initializer instead - `Text("Total")`; a control made empty
    /// says it here.
    public func text(_ value: String) -> Modified { setValue(TextualElementContract.text, value) }

    /// `textCase` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func textCase(_ state: Binding<TextCase>) -> Modified {
        twin(TextualElementContract.textCase, by: state)
    }
}
