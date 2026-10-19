// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control whose text is a property: everything `TextStyleElement` has,
/// plus the text itself.
public protocol TextualElement: TextStyleElement {}

extension TextualElement {
    /// What the control says. Usually given in the initializer instead -
    /// `Text("Total")` - and this is the way to change it in a style.
    public func text(_ value: String) -> Modified { setValue(TextualElementContract.text, value) }

    /// Whether the letters are drawn as written or in one case throughout.
    ///
    ///     Text("total").textCase(.uppercase)
    public func textCase(_ value: TextCase) -> Modified {
        setValue(TextualElementContract.textCase, value)
    }
}

extension TextualElement where Self: VisualElement {
    /// `textCase` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func textCase(_ state: Binding<TextCase>) -> Modified {
        twin(TextualElementContract.textCase, by: state)
    }
}
