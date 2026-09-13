// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How tall a line of text stands.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and a line height is a Label's and a span's.

/// The height of a text line, relative to the font's own.
/// MAUI: ILineHeightElement - the interface Label and Span both implement.
///
/// `PropertyContainer` rather than a view tier: a `TextSpan` wears this and
/// is not a view, and a `Style` wears it without being in the tree at all.
public protocol LineHeightElement: PropertyContainer {}

extension LineHeightElement {
    /// The height of a line, as a MULTIPLE of the font's own - 1.5 for half
    /// again. MAUI: LineHeight. Said nothing about, the font's own height
    /// stands.
    public func lineHeight(_ value: Double) -> Modified {
        setValue(.lineHeight, .number(value))
    }
}
