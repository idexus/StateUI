// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A name from an open vocabulary - a font family, a style key, a radio group,
/// a kept value's key: words an application chose, repeated across a tree and
/// meaning the same thing every time.
///
///     static let theme = ElementProperty<Self, Name>("theme")
///
/// Declare a member as `Name` for such words, and as `String` for text an
/// author wrote: the two cross to a host differently.
///
/// Design: docs/design/types/values.md#text-and-names
public struct Name: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible,
    HostRepresentable {
    /// The name, spelled.
    public let text: String

    /// A name, spelled.
    ///
    /// - Parameter text: the name.
    public init(_ text: String) {
        self.text = text
    }

    /// A name written as a literal: `"Headline"`.
    ///
    /// - Parameter text: the name.
    public init(stringLiteral text: String) {
        self.text = text
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { text }

    /// The name, as a name.
    public var propValue: PropValue { .name(text) }

    /// The name back - nil for any other kind, text included.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .name(let text) = propValue else { return nil }

        self.text = text
    }
}
