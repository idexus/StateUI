// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The keyboard over a phone's page, from the part of the page its browser leaves visible.
/// Design: docs/design/platforms/web/pages.md#the-keyboard
enum WebScreenKeyboard {
    static func height(layout: Double, top: Double, visible: Double, scale: Double) -> Double {
        guard abs(scale - 1) < 0.001 else { return 0 }
        return max(0, (layout - top - visible).rounded())
    }
}
