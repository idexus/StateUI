// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line under the text, through it, or both - worn by `Label` and
/// `TextSpan`.
public protocol DecorableTextElement: PropertyContainer {}

extension DecorableTextElement {
    /// A line under the text, through it, or both.
    ///
    ///     Label("Sold out").textDecorations(.strikethrough)
    public func textDecorations(_ value: TextDecorations) -> Modified {
        setValue(DecorableTextElementContract.textDecorations, value)
    }
}

extension DecorableTextElement where Self: VisualElement {
    /// `textDecorations` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func textDecorations(_ state: Binding<TextDecorations>) -> Modified {
        plain(DecorableTextElementContract.textDecorations, by: state)
    }
}
