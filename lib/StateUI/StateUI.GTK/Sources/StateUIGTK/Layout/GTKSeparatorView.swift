// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A separator in a stack: a `GtkSeparator`, its line running across its stack - down a row, along a column - as
/// thick as the theme draws one.
/// Design: docs/design/host/layout.md#a-separator-in-a-stack
@MainActor
final class GTKSeparatorView: GTKView {
    init(inRow: Bool) {
        super.init { _ in gtk_separator_new(inRow ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL) }
    }
}
