// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// The battery as the desktop knows it: UPower's display device on the system bus, which GNOME's own power status
/// reads too.
@MainActor
enum GalleryPower {
    /// UPower's display device; nil where the system bus has no UPower.
    static let device: UnsafeMutablePointer<GDBusProxy>? = g_dbus_proxy_new_for_bus_sync(
        G_BUS_TYPE_SYSTEM, G_DBUS_PROXY_FLAGS_NONE, nil, "org.freedesktop.UPower",
        "/org/freedesktop/UPower/devices/DisplayDevice", "org.freedesktop.UPower.Device", nil, nil)

    /// The battery's level, 0 through 1, and whether the power is plugged in - both zero and false on a desktop that
    /// has no battery to report, which is an ordinary answer rather than a failure.
    static func battery() -> (Double, Bool) {
        guard let device, value("IsPresent", of: device, g_variant_get_boolean) != 0 else { return (0, false) }
        let percentage = value("Percentage", of: device, g_variant_get_double) ?? 0
        // Charging 1, fully charged 4, pending a charge 5: the power is plugged in.
        let state = value("State", of: device, g_variant_get_uint32) ?? 0
        return (percentage / 100, [1, 4, 5].contains(state))
    }

    private static func value<Read>(
        _ name: String, of device: UnsafeMutablePointer<GDBusProxy>, _ read: (OpaquePointer?) -> Read
    ) -> Read? {
        guard let variant = g_dbus_proxy_get_cached_property(device, name) else { return nil }
        defer { g_variant_unref(variant) }
        return read(variant)
    }
}
