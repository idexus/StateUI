// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The band behind an item the user chose, where a host draws it from the accent: the accent's hue at a fifth of its
/// strength.
/// Design: docs/design/host/items.md#the-chosen-band
@_spi(Host) public enum ChosenBand {
    /// The opacity the band is drawn at.
    public static let opacity = 0.2

    /// The band over `accent`, both packed in one number, eight bits a channel with alpha highest.
    public static func argb(over accent: UInt32) -> UInt32 {
        accent & 0x00FF_FFFF | UInt32(ColorChannel.nearest(opacity)) << 24
    }
}
