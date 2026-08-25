// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How the text of a control is set in type.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and a font is the texted controls', a span's and a
// style's.

/// How the text of a control is set in type - its size, its family, its
/// weight. MAUI: IFontElement.
///
/// `PropertyContainer` rather than a view tier: a `TextSpan` wears this and
/// is not a view, and a `Style` wears it without being in the tree at all.
public protocol FontElement: PropertyContainer {}

extension FontElement {
    /// How big the text is, in device units. MAUI: FontSize.
    public func fontSize(_ value: Double) -> Modified { setValue(.fontSize, .number(value)) }

    /// Which font, by the alias the app registered it under - not the file name.
    /// MAUI: FontFamily, registered with `fonts.AddFont("X.ttf", "X")`.
    ///
    /// That alias is a NAME, not prose: it stands for a registered resource and
    /// repeats on every view using the font, so it rides the session's
    /// dictionary as a number rather than being spelled out per control.
    public func fontFamily(_ value: String) -> Modified { setValue(.fontFamily, .name(value)) }

    /// Bold, italic, or both. MAUI: FontAttributes.
    ///
    ///     Label("Total").fontAttributes([.bold, .italic])
    public func fontAttributes(_ value: FontAttributes) -> Modified { setValue(.fontAttributes, value.propValue) }

    /// Whether the text grows with the system's text-size setting. On by
    /// default. MAUI: FontAutoScalingEnabled.
    public func fontAutoScalingEnabled(_ value: Bool) -> Modified { setValue(.fontAutoScalingEnabled, .bool(value)) }
}
