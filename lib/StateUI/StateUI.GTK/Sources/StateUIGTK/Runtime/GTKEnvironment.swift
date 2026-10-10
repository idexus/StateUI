// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// What the device, the application, the desktop's style and the screen are, told to the core as the host starts,
/// and again whenever the desktop says one changed; and what the user asks of motion.
/// Design: docs/design/platforms/gtk/runtime.md#the-environment
@MainActor
enum GTKEnvironment {
    /// Tells `core` what the host stands on: what never changes, then what may.
    static func report(to core: CoreLink, applicationID: String) {
        let model = system("/sys/devices/virtual/dmi/id/product_name")
        let maker = system("/sys/devices/virtual/dmi/id/sys_vendor")
        let virtual = ["Virtual", "VMware", "QEMU", "KVM", "Parallels", "VirtualBox"].contains {
            model.contains($0) || maker.contains($0)
        }
        core.setDeviceInfo(HostDeviceInfo(
            formFactor: .desktop, platform: "Linux", model: model, manufacturer: maker,
            name: g_get_host_name().map { String(cString: $0) } ?? "",
            versionString: osInfo("VERSION_ID"), deviceType: virtual ? .virtual : .physical))
        core.setApplicationInfo(HostApplicationInfo(
            name: g_get_application_name().map { String(cString: $0) } ?? "", packageName: applicationID,
            versionString: "", buildString: ""))
        reportChanging(to: core)
    }

    /// Tells `core` what may change as it stands now: the desktop's style, dark or light, and its accent, the
    /// locale, the power and the network.
    static func reportChanging(to core: CoreLink) {
        let style = adw_style_manager_get_default()
        core.setColorScheme(adw_style_manager_get_dark(style) != 0 ? .dark : .light)
        core.setAccentColor(accent)
        core.setLocaleInfo(locale)
        core.setBatteryInfo(battery)
        core.setConnectivityInfo(connectivity)
    }

    /// Calls `changed` whenever the desktop's style turns dark or light, its accent changes where libadwaita offers
    /// one to choose, or the power or the network change.
    static func watch(_ changed: @escaping @MainActor () -> Void) {
        onChange = changed
        watchMachine(changed)
        guard !watching else { return }
        watching = true
        let style = adw_style_manager_get_default()!
        connectNotify(UnsafeMutableRawPointer(style), "dark", number: 0) { _, _, _ in
            MainActor.assumeIsolated { GTKEnvironment.onChange?() }
        }
        // The accent the user chooses, where libadwaita offers one to choose (1.6 on).
        if offersAccent {
            connectNotify(UnsafeMutableRawPointer(style), "accent-color", number: 0) { _, _, _ in
                MainActor.assumeIsolated { GTKEnvironment.onChange?() }
            }
        }
    }

    private static var watching = false

    /// Whether libadwaita offers the user an accent to choose - from 1.6 on.
    static var offersAccent: Bool {
        let styles = g_type_class_peek(adw_style_manager_get_type())?.assumingMemoryBound(to: GObjectClass.self)
        return styles.map { g_object_class_find_property($0, "accent-color") != nil } ?? false
    }

    /// A label of libadwaita's `accent` class, never shown, whose colour is the accent the desktop draws.
    private static var accentProbe: UnsafeMutablePointer<GtkWidget>?

    /// The accent the desktop draws in, as libadwaita's `accent` class colours words.
    static var accent: Color {
        let probe = accentProbe ?? {
            let label = gtk_label_new(nil)!
            g_object_ref_sink(label)
            gtk_widget_add_css_class(label, "accent")
            accentProbe = label
            return label
        }()
        var rgba = GdkRGBA()
        gtk_widget_get_color(probe, &rgba)
        func channel(_ value: Float) -> Int { Int((value * 255).rounded()) }
        return Color(red: channel(rgba.red), green: channel(rgba.green), blue: channel(rgba.blue),
                     alpha: channel(rgba.alpha))
    }
    private static var onChange: (@MainActor () -> Void)?

    /// Tells `core` the screen `window` stands on: its size in pixels, its scale, its refresh rate.
    static func reportDisplay(to core: CoreLink, window: GTKWidget) {
        guard let surface = gtk_native_get_surface(window.opaque), let display = gdk_surface_get_display(surface),
              let monitor = gdk_display_get_monitor_at_surface(display, surface)
        else { return }

        var area = GdkRectangle()
        gdk_monitor_get_geometry(monitor, &area)
        let scale = gdk_monitor_get_scale(monitor)
        let width = Double(area.width) * scale
        let height = Double(area.height) * scale
        core.setDisplayInfo(HostDisplayInfo(
            width: width, height: height, density: scale,
            refreshRate: Double(gdk_monitor_get_refresh_rate(monitor)) / 1_000))
    }

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

    /// A line of the system's own, read from a file of the kernel's; empty where it has none.
    private static func system(_ path: String) -> String {
        var contents: UnsafeMutablePointer<gchar>?
        guard g_file_get_contents(path, &contents, nil, nil) != 0, let contents else { return "" }
        defer { g_free(contents) }
        var line = String(cString: contents)
        while line.last?.isNewline == true { line.removeLast() }
        return line
    }

    /// A field of the operating system's own description.
    private static func osInfo(_ key: String) -> String {
        guard let value = g_get_os_info(key) else { return "" }
        defer { g_free(value) }
        return String(cString: value)
    }
}
