// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// The input method GTK hands a field the keyboard through, bound on each display before any field can go.
/// Design: docs/design/platforms/gtk/runtime.md#the-input-method
@MainActor
enum GTKInputMethod {
    private static var boundDisplays: Set<UInt> = []

    /// Waits, as the first field on `field`'s display takes the keyboard, for the compositor to answer its input method.
    static func bind(for field: GTKWidget) {
        guard let display = gtk_widget_get_display(field), boundDisplays.insert(UInt(bitPattern: display)).inserted
        else { return }
        gdk_display_sync(display)
    }
}
