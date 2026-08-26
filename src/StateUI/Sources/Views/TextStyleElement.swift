// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The colour and spacing of a control's text, without the text itself.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and this one is worn by the controls that colour
// text, by `TextSpan`, which is not a view, and by a `Style`, which is not in
// the tree at all.

/// MAUI: ITextElement - TextColor and CharacterSpacing, WITHOUT the text
/// itself.
///
/// Two tiers rather than one, because MAUI has controls that colour their text
/// and have no Text property to say it with: a Picker shows the chosen item, a
/// DatePicker and a TimePicker format a value, a RadioButton captions itself
/// with Content. Each carries TextColor and CharacterSpacing all the same, so
/// this is the tier they join - and a control that also SAYS something takes
/// `TextElement`, one step up.
///
/// `PropertyContainer` rather than a view tier, twice over: MAUI's `Span`
/// wears this interface and is not a view, and a `Style` wears it without
/// being in the tree at all.
public protocol TextStyleElement: PropertyContainer {}

extension TextStyleElement {
    /// The colour of the text. MAUI: TextColor.
    ///
    /// A `Color(light:dark:)` here is resolved as it is written, the read
    /// recorded - a theme change rebuilds the views that asked, and the other
    /// half is written then.
    public func textColor(_ value: Color) -> Modified { setValue(.textColor, value.propValue) }

    /// The space added between letters, in device units.
    /// MAUI: CharacterSpacing.
    public func characterSpacing(_ value: Double) -> Modified { setValue(.characterSpacing, .number(value)) }
}
