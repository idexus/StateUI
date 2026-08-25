// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tier for a control whose text IS a property.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and Text is four controls' and a span's.

/// The tier for a control whose text IS a property: everything
/// `TextStyleElement` has, plus the text itself.
///
/// MAUI declares Text per control - Label.Text, Button.Text, InputView.Text,
/// Span.Text - rather than on ITextElement, which is why the tiers are two: a
/// Picker colours its text and has no Text to set, so it stops one tier down,
/// and `.text()` on it would compile and do nothing.
public protocol TextElement: TextStyleElement {}

extension TextElement {
    /// What the control says. Usually given in the initializer instead -
    /// `Label("Total")` - and this is the way to change it in a style.
    /// MAUI: Text.
    public func text(_ value: String) -> Modified { setValue(.text, .string(value)) }

    /// Whether those letters are DRAWN as written or in one case throughout.
    /// MAUI: TextTransform.
    ///
    ///     Label("total").textTransform(.uppercase)
    ///
    /// On this tier rather than on `TextStyleElement`, and MEASURED against
    /// MAUI 10.0.20 rather than assumed: `TextElement.TextTransformProperty` is
    /// re-exposed by Label, Button, InputView and Span - which is exactly this
    /// tier - while Picker, DatePicker and TimePicker implement `ITextElement`
    /// explicitly and hard-code the transform to `Default`, with no bindable
    /// property to write. A modifier there would compile and do nothing.
    /// `RadioButton` is the one control that has it without having a `Text`,
    /// and carries its own.
    public func textTransform(_ value: TextTransform) -> Modified {
        setValue(.textTransform, value.propValue)
    }
}
