// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// What the desktop says about the user's settings, read from GTK's.
@MainActor
enum GTKEnvironment {
    /// Whether the user asked for less motion: the desktop's animations turned off.
    /// Design: docs/design/platforms/gtk/motion.md#less-motion
    static var reducesMotion: Bool {
        guard let settings = gtk_settings_get_default() else { return false }

        var value = GValue()
        g_value_init(&value, g_type_from_name("gboolean"))
        defer { g_value_unset(&value) }
        g_object_get_property(UnsafeMutablePointer<GObject>(settings), "gtk-enable-animations", &value)
        return g_value_get_boolean(&value) == 0
    }
}
