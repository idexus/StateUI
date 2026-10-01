// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control whose text is a property: everything `TextStyleElement` has,
/// plus the text itself.
public protocol TextElement: TextStyleElement {}

extension TextElement {
    /// What the control says. Usually given in the initializer instead -
    /// `Label("Total")` - and this is the way to change it in a style.
    public func text(_ value: String) -> Modified { setValue(TextElementContract.text, value) }

    /// Whether the letters are drawn as written or in one case throughout.
    ///
    ///     Label("total").textCase(.uppercase)
    public func textCase(_ value: TextCase) -> Modified {
        setValue(TextElementContract.textCase, value)
    }
}
