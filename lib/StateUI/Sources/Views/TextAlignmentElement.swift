// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a control's text sits inside the control.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and an inner text alignment is the texted
// controls' alone.

/// Where a control's text sits INSIDE the control.
/// MAUI: ITextAlignmentElement.
///
/// Not where the control sits in its parent, which is `horizontalOptions` and
/// `verticalOptions` on View - the trap this tier exists next to.
public protocol TextAlignmentElement: VisualElementProperties {}

extension TextAlignmentElement {
    /// Where the text sits within the control's own width.
    /// MAUI: HorizontalTextAlignment.
    ///
    /// Not the same as `horizontalOptions`, which is where the CONTROL sits
    /// within its parent - a centred label in a left-aligned control looks
    /// like neither.
    public func horizontalTextAlignment(_ value: TextAlignment) -> Modified {
        setValue(.horizontalTextAlignment, value.propValue)
    }

    /// Where the text sits within the control's own height.
    /// MAUI: VerticalTextAlignment.
    public func verticalTextAlignment(_ value: TextAlignment) -> Modified {
        setValue(.verticalTextAlignment, value.propValue)
    }
}
