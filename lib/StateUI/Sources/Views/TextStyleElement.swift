// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The colour and spacing of a control's text, without the text itself.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and this one is worn by the controls that colour
// text, by `TextSpan`, which is not a view, and by a `Style`, which is not in
// the tree at all.

/// The colour and letter spacing of a control's text, WITHOUT the text
/// itself.
///
/// Two tiers rather than one, because some controls colour their text and
/// have no text property to say it with: a Picker shows the chosen item, and
/// a DatePicker and a TimePicker format a value. Each carries `textColor` and
/// `characterSpacing` all the same, so this is the tier they join - and a
/// control that also SAYS something takes `TextElement`, one step up.
///
/// `PropertyContainer` rather than a view tier, twice over: a `TextSpan`
/// wears this tier and is not a view, and a `Style` wears it without being
/// in the tree at all.
public protocol TextStyleElement: PropertyContainer {}

extension TextStyleElement {
    /// The colour of the text.
    ///
    /// A `Color(light:dark:)` here carries both halves; the differ picks the
    /// one the theme asks for as it builds the view, so a theme change builds
    /// again exactly the views wearing a pair.
    public func textColor(_ value: Color) -> Modified { setValue(.textColor, value.propValue) }

    /// The space added between letters, in device units.
    public func characterSpacing(_ value: Double) -> Modified { setValue(.characterSpacing, .number(value)) }
}
