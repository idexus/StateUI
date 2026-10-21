// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// What the device, the application, the desktop's style, the screen and the user's accessibility settings are, told
/// to the core as the host starts, and again whenever the desktop says one changed.
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
            versionString: osInfo("VERSION_ID"), isVirtual: virtual))
        core.setApplicationInfo(HostApplicationInfo(
            name: g_get_application_name().map { String(cString: $0) } ?? "", packageName: applicationID,
            versionString: "", buildString: ""))
        reportChanging(to: core)
    }

    /// Tells `core` what may change as it stands now: the desktop's style, dark or light, and its accent, the
    /// locale, the power, the network and the accessibility settings.
    static func reportChanging(to core: CoreLink) {
        let style = adw_style_manager_get_default()
        core.setColorScheme(adw_style_manager_get_dark(style) != 0 ? .dark : .light)
        core.setAccentColor(accent)
        core.setLocaleInfo(locale)
        core.setBatteryInfo(battery)
        core.setConnectivityInfo(connectivity)
        core.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: reducesMotion, prefersHigherContrast: adw_style_manager_get_high_contrast(style) != 0,
            isScreenReaderOn: isScreenReaderOn, textScale: textScale))
    }

    /// Calls `changed` whenever the desktop's style turns dark or light or its contrast changes, its accent changes
    /// where libadwaita offers one to choose, the power or the network change, or an accessibility setting does.
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
        watchAccessibility(style)
    }

    /// Watches the desktop's contrast, its animations, its text scale and GNOME's screen reader.
    private static func watchAccessibility(_ style: OpaquePointer) {
        connectNotify(UnsafeMutableRawPointer(style), "high-contrast", number: 0) { _, _, _ in
            MainActor.assumeIsolated { GTKEnvironment.onChange?() }
        }
        if let settings = gtk_settings_get_default() {
            for property in ["gtk-enable-animations", "gtk-xft-dpi"] {
                connectNotify(UnsafeMutableRawPointer(settings), property, number: 0) { _, _, _ in
                    MainActor.assumeIsolated { GTKEnvironment.onChange?() }
                }
            }
        }
        if let reader = readerSettings {
            connectSignal(UnsafeMutableRawPointer(reader), "changed::screen-reader-enabled", number: 0) {
                (_: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, _: gpointer?) in
                MainActor.assumeIsolated { GTKEnvironment.onChange?() }
            }
        }
    }

    /// GNOME's settings of its assistive applications, kept for the process; none on a desktop keeping no such
    /// settings, where asking for them would end the process.
    private static let readerSettings: UnsafeMutablePointer<GSettings>? = {
        let schema = "org.gnome.desktop.a11y.applications"
        guard let source = g_settings_schema_source_get_default(),
              let found = g_settings_schema_source_lookup(source, schema, 1)
        else { return nil }
        g_settings_schema_unref(found)
        return g_settings_new(schema)
    }()

    /// Whether GNOME's screen reader is on; off on a desktop keeping no such setting.
    static var isScreenReaderOn: Bool {
        readerSettings.map { g_settings_get_boolean($0, "screen-reader-enabled") != 0 } ?? false
    }

    private static var watching = false

    /// Whether libadwaita offers the user an accent to choose - from 1.6 on, once its style manager stands: before
    /// it, GTK knows no class to look in.
    static var offersAccent: Bool {
        let styles = g_type_class_peek(adw_style_manager_get_type())?.assumingMemoryBound(to: GObjectClass.self)
        return styles.map { g_object_class_find_property($0, "accent-color") != nil } ?? false
    }

    /// A label of libadwaita's `accent` class, never shown, whose color is the accent the desktop draws.
    private static var accentProbe: UnsafeMutablePointer<GtkWidget>?

    /// The accent the desktop draws in, as libadwaita's `accent` class colors words.
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
        return Color(fractions: (Double(rgba.red), Double(rgba.green), Double(rgba.blue), Double(rgba.alpha)))
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

    /// The desktop's text scale - what GNOME's text size multiplies words by: its dots an inch over 96.
    /// Design: docs/design/platforms/gtk/controls.md#words
    static var textScale: Double {
        guard let settings = gtk_settings_get_default() else { return 1 }

        var value = GValue()
        g_value_init(&value, g_type_from_name("gint"))
        defer { g_value_unset(&value) }
        g_object_get_property(UnsafeMutablePointer<GObject>(settings), "gtk-xft-dpi", &value)
        let dpi = Double(g_value_get_int(&value))
        return dpi > 0 ? dpi / (96 * 1024) : 1
    }

    /// The size of the desktop's own font before its text scale, in StateUI's points - what words stand at where the
    /// tree gives none: GNOME's 11 typographic points where the desktop names no font.
    static var fontSize: Double {
        var value = GValue()
        g_value_init(&value, g_type_from_name("gchararray"))
        defer { g_value_unset(&value) }
        if let settings = gtk_settings_get_default() {
            g_object_get_property(UnsafeMutablePointer<GObject>(settings), "gtk-font-name", &value)
        }
        guard let name = g_value_get_string(&value), let font = pango_font_description_from_string(name),
              pango_font_description_get_size(font) > 0
        else { return 11 * 96 / 72 }
        defer { pango_font_description_free(font) }
        let size = Double(pango_font_description_get_size(font)) / Double(PANGO_SCALE)
        return pango_font_description_get_size_is_absolute(font) != 0 ? size : size * 96 / 72
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
