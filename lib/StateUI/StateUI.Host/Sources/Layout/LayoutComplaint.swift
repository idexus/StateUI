// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host says where its toolkit gave up laying a window out, the same on every host: the application goes on.
/// Design: docs/design/host/layout.md#a-layout-that-does-not-settle
@_spi(Host) public enum LayoutComplaint {
    /// A window's layout ran again at every pass on `platform` until its toolkit gave up.
    public static func didNotSettle(on platform: String) -> String {
        "A window's layout did not settle on \(platform): its views were measured and placed again at every pass "
            + "until the toolkit gave up. The pass ended where it stood, and a size or a place in the window may be "
            + "off."
    }
}
