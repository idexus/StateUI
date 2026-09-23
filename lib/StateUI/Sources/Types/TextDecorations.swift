// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// The lines drawn through or under text.
///
///     Label("$40").textDecorations(.strikethrough)
public struct TextDecorations: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.underline`, `.strikethrough` and both together are
    /// the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Plain text.
    public static let none = TextDecorations([])

    /// A line under the text.
    public static let underline = TextDecorations(rawValue: 1 << 0)

    /// A line through it.
    public static let strikethrough = TextDecorations(rawValue: 1 << 1)
}

extension TextDecorations: HostRepresentable {}
extension TextDecorations: StateChoice {}
