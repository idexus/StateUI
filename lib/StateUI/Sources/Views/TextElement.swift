// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tier for a control whose text IS a property.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and Text is the texted controls' and a span's.

/// The tier for a control whose text IS a property: everything
/// `TextStyleElement` has, plus the text itself.
///
/// The tiers are separate because a Picker or date/time field can style the
/// value it formats without owning an independent text value.
public protocol TextElement: TextStyleElement {}

extension TextElement {
    /// What the control says. Usually given in the initializer instead -
    /// `Label("Total")` - and this is the way to change it in a style.
    public func text(_ value: String) -> Modified { setValue(.text, .string(value)) }

    /// Whether those letters are DRAWN as written or in one case throughout.
    ///
    ///     Label("total").textTransform(.uppercase)
    ///
    /// On this tier rather than on `TextStyleElement`, because transforming a
    /// formatted picker value would be a different, platform-specific promise.
    public func textTransform(_ value: TextTransform) -> Modified {
        setValue(.textTransform, value.propValue)
    }
}
