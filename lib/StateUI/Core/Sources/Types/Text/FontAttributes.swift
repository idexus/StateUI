// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Whether text is drawn bold, italic, or both.
///
///     Label("Total").fontAttributes(.bold)
///     Label("Total").fontAttributes([.bold, .italic])
///
/// Only the weight and the slant: the family is `.fontFamily` and the size
/// `.fontSize`, each its own modifier as it is its own property.
public struct FontAttributes: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.bold`, `.italic` and `[.bold, .italic]` are the
    /// ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Neither bold nor italic.
    public static let none = FontAttributes([])

    /// Drawn bold.
    public static let bold = FontAttributes(rawValue: 1 << 0)

    /// Drawn italic.
    public static let italic = FontAttributes(rawValue: 1 << 1)
}

extension FontAttributes: HostRepresentable {}
extension FontAttributes: StateChoice {}
