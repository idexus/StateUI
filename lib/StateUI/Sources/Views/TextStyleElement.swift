// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The colour and letter spacing of a control's text, without the text
/// itself - worn by the pickers too, which format a value rather than show a
/// text of their own. A control that says something wears `TextElement`.
public protocol TextStyleElement: PropertyContainer {}

extension TextStyleElement {
    /// The colour of the text; a `Color(light:dark:)` follows the system theme.
    public func textColor(_ value: Color) -> Modified { setValue(TextStyleElementContract.textColor, value) }

    /// The space added between letters, in device units.
    public func characterSpacing(_ value: Double) -> Modified { setValue(TextStyleElementContract.characterSpacing, value) }
}
