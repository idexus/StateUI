// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The lines drawn through or under text.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and a decoration is a Label's and a span's.

/// A line under the text, through it, or both.
/// MAUI: IDecorableTextElement - the interface Label and Span both implement.
///
/// `PropertyContainer` rather than a view tier: a `TextSpan` wears this and
/// is not a view, and a `Style` wears it without being in the tree at all.
public protocol DecorableTextElement: PropertyContainer {}

extension DecorableTextElement {
    /// A line under the text, through it, or both.
    /// MAUI: TextDecorations.
    ///
    ///     Label("Sold out").textDecorations(.strikethrough)
    public func textDecorations(_ value: TextDecorations) -> Modified {
        setValue(.textDecorations, value.propValue)
    }
}
