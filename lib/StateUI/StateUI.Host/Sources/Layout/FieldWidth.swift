// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How wide a one-line field asks to be where nothing sizes it - the same on every host: at least as wide as twenty
/// digits and as its placeholder, each measured in the field's own font, the platform's own width standing where it
/// is wider.
/// Design: docs/design/host/layout.md#a-fields-own-width
@_spi(Host) public enum FieldWidth {
    /// How many digits every field is at least as wide as.
    public static let digits = 20

    /// The words a field is at least as wide as - each measured in its font, the widest standing - with
    /// `placeholder` shown while it is empty.
    public static func leastWords(placeholder: String?) -> [String] {
        let least = String(repeating: "0", count: digits)
        guard let placeholder, !placeholder.isEmpty else { return [least] }
        return [least, placeholder]
    }

    /// The width a field asks for: the platform's own, else the widest of `measured` - its least words in its
    /// font - with `chrome`, what the field draws around its words.
    public static func width(own: Double?, measured: [Double], chrome: Double) -> Double {
        let least = (measured.max() ?? 0) + chrome
        return max(own ?? 0, least)
    }
}
