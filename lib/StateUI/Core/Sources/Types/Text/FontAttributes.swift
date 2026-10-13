// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/vocabularies.md#flag-sets-carry-bits

/// Whether text is drawn italic.
///
///     Text("Total").fontAttributes(.italic)
///
/// Only the slant: the weight is `.fontWeight`, the family `.fontFamily` and
/// the size `.fontSize`, each its own modifier as it is its own property.
public struct FontAttributes: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.italic` is the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Upright.
    public static let none = FontAttributes([])

    /// Drawn italic.
    public static let italic = FontAttributes(rawValue: 1 << 1)
}

extension FontAttributes: HostRepresentable {}
extension FontAttributes: StateChoice {}
