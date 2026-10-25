// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The color a color picker shows and reports, the same on every host: the tree's color, black where it gives none;
/// the user's choice at its nearest channels, opaque where the picker does not choose opacity.
/// Design: docs/design/host/runtime.md#a-color-chosen
@_spi(Host) public enum ColorChoice {
    /// The color a picker shows where the tree gives none.
    public static let unset = Color.black

    /// What a picker reports of the color the user chose, which its toolkit gives as four fractions of full.
    public static func reported(
        _ fractions: (red: Double, green: Double, blue: Double, alpha: Double), choosesOpacity: Bool
    ) -> Color {
        Color(fractions: (fractions.red, fractions.green, fractions.blue, choosesOpacity ? fractions.alpha : 1))
    }
}
