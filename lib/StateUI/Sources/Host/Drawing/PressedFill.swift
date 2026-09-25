// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How opaque a control's own fill - a button's background, an accent - is drawn as the user reaches for it, the
/// same on every host drawing that fill itself: a little fainter under the pointer, fainter still pressed.
/// Design: docs/design/host/layout.md#a-box
@_spi(Host) public enum PressedFill {
    /// The share of its opacity a fill keeps under the pointer.
    public static let underPointer = 0.9

    /// The share of its opacity a fill keeps pressed.
    public static let pressed = 0.8
}
