// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The colour of a control's text, without the text itself - worn by the
/// pickers too, which format a value rather than show a text of their own. A
/// control that says something wears `TextualElement`.
public protocol TextStyleElement: PropertyContainer {}

extension TextStyleElement {
    /// The colour of the text; a `Color(light:dark:)` follows the system theme.
    public func textColor(_ value: Color) -> Modified { setValue(TextStyleElementContract.textColor, value) }
}

extension TextStyleElement where Self: VisualElement {
    /// `textColor` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func textColor(_ state: Binding<Color>) -> Modified {
        twin(TextStyleElementContract.textColor, by: state)
    }
}
