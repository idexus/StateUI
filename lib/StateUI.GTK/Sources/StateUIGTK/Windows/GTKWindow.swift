// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// An application window of libadwaita, showing a page in a frame of its own - its header bar the window's title
/// bar - or an arrangement whose pages carry theirs; presented the first time it shows something.
/// Design: docs/design/platforms/gtk/runtime.md#the-window
@MainActor
final class GTKWindow {
    /// The `AdwApplicationWindow`, held until this is released.
    let widget: GTKWidget

    /// The number its signals carry to the runtime, one across the process.
    let number: Int64
    private static var nextNumber: Int64 = 1

    /// Whether the window has closed - the user's close or the tree's.
    private(set) var isClosed = false

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows: a page's, or an arrangement's.
    private(set) var content: GTKView?

    /// The frame a page shown by itself stands in; nil while the window shows an arrangement.
    private(set) var pageFrame: GTKPageFrame?

    /// The layers the window's content and its overlays stand in.
    private let layers: GTKWidget

    /// What the window lays over everything it shows; nil for nothing.
    private(set) var overlays: [GTKView] = []

    private var presented = false

    /// Whether its scene hides it.
    private var isHidden = false

    init(application: UnsafeMutablePointer<GtkApplication>) {
        widget = adw_application_window_new(application)!
        g_object_ref(widget)
        number = Self.nextNumber
        Self.nextNumber += 1
        gtk_window_set_default_size(widget.of(GtkWindow.self), 560, 440)
        // GNOME's smallest window, which a window that adapts to its width must say.
        gtk_widget_set_size_request(widget, 360, 294)
        layers = gtk_overlay_new()!
        g_object_ref_sink(layers)
        adw_application_window_set_content(widget.of(AdwApplicationWindow.self), layers)
        hearItsLife()
    }

    /// A window let go of tells nobody it went: its handlers leave before GTK destroys it.
    isolated deinit {
        let data = UnsafeMutableRawPointer(bitPattern: Int(number))
        g_signal_handlers_disconnect_matched(UnsafeMutableRawPointer(widget), G_SIGNAL_MATCH_DATA, 0, 0, nil, nil, data)
        if let surface = gtk_native_get_surface(widget.opaque) {
            g_signal_handlers_disconnect_matched(UnsafeMutableRawPointer(surface), G_SIGNAL_MATCH_DATA, 0, 0, nil, nil, data)
        }
        gtk_window_destroy(widget.of(GtkWindow.self))
        g_object_unref(layers)
        g_object_unref(widget)
    }

    /// Tells the runtime the window's life as GTK tells it: going, active or not, minimized or not.
    /// Design: docs/design/platforms/gtk/runtime.md#a-windows-life
    private func hearItsLife() {
        let window = UnsafeMutableRawPointer(widget)
        // The close button and Alt+F4 ask to close; GTK then closes the window.
        connectAnswering(window, "close-request", number: number) { _, data in
            MainActor.assumeIsolated { GTKRenderer.shared?.windowClosed(number: viewNumber(data)) }
            return 0
        }
        connectNotify(window, "is-active", number: number) { _, _, data in
            MainActor.assumeIsolated { GTKRenderer.shared?.windowStateChanged(number: viewNumber(data)) }
        }
        connectSignal(window, "realize", number: number) { window, data in
            guard let native = window, let surface = gtk_native_get_surface(OpaquePointer(native)) else { return }
            connectNotify(UnsafeMutableRawPointer(surface), "state", number: viewNumber(data)) { _, _, data in
                MainActor.assumeIsolated { GTKRenderer.shared?.windowStateChanged(number: viewNumber(data)) }
            }
        }
    }

    /// Whether the user is in the window now.
    var isActive: Bool {
        gtk_window_is_active(widget.of(GtkWindow.self)) != 0
    }

    /// Whether the window stands minimized, where the desktop says so - a Wayland desktop says nothing of it.
    var isMinimized: Bool {
        guard let surface = gtk_native_get_surface(widget.opaque),
              g_type_check_instance_is_a(UnsafeMutablePointer<GTypeInstance>(surface), gdk_toplevel_get_type()) != 0
        else { return false }
        return gdk_toplevel_get_state(surface).rawValue & GDK_TOPLEVEL_STATE_MINIMIZED.rawValue != 0
    }

    /// The window's name, to the desktop - its switcher, its dock; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        gtk_window_set_title(widget.of(GtkWindow.self), title)
    }

    /// The size the tree asks the window for, each side alone; a window already open takes it too. Its place is the
    /// desktop's: GNOME places its windows itself.
    /// Design: docs/design/platforms/gtk/runtime.md#a-windows-frame
    func request(_ frame: WindowFrame) {
        guard frame.width != nil || frame.height != nil else { return }
        var current: (width: Int32, height: Int32) = (0, 0)
        gtk_window_get_default_size(widget.of(GtkWindow.self), &current.width, &current.height)
        gtk_window_set_default_size(
            widget.of(GtkWindow.self), frame.width.map { Int32($0) } ?? current.width,
            frame.height.map { Int32($0) } ?? current.height)
    }

    /// How small the user may make the window; GNOME's smallest where the element says none. GTK bounds no window
    /// from above.
    func bound(_ bounds: WindowBounds) {
        gtk_widget_set_size_request(widget, Int32(bounds.minimumWidth ?? 360), Int32(bounds.minimumHeight ?? 294))
    }

    /// Hides the window while its scene hides it, and shows it again.
    func setHidden(_ hidden: Bool) {
        guard hidden != isHidden else { return }
        isHidden = hidden
        if presented { gtk_widget_set_visible(widget, hidden ? 0 : 1) } else if !hidden, content != nil { firstPresent() }
    }

    /// Makes the window `owner`'s - above it, and gone with it - or, for nil, one of its own.
    func setOwner(_ owner: GTKWindow?) {
        gtk_window_set_transient_for(widget.of(GtkWindow.self), owner?.widget.of(GtkWindow.self))
        gtk_window_set_destroy_with_parent(widget.of(GtkWindow.self), owner == nil ? 0 : 1)
    }

    /// Shows `view` as the window's content, as it stands: an arrangement whose pages carry their header bars.
    func show(_ view: GTKView?) {
        guard view !== content || pageFrame != nil else { return }
        content = view
        pageFrame = nil
        setContent(view?.widget)
    }

    /// Shows `page` in a frame of its own, whose header bar is the window's title bar.
    func show(page: GTKView?) {
        guard page !== content || pageFrame == nil else { return }
        content = page
        pageFrame = page.map { GTKPageFrame(page: $0) }
        setContent(pageFrame?.widget)
    }

    /// Lays `views` over everything the window shows, where the page stands, the first lowest; none takes them away.
    /// Design: docs/design/platforms/gtk/pages.md#the-windows-overlays
    func showOverlays(_ views: [GTKView]) {
        guard !views.elementsEqual(overlays, by: ===) else { return }
        for leaving in overlays { gtk_overlay_remove_overlay(layers.opaque, leaving.widget) }
        overlays = views
        for view in views { gtk_overlay_add_overlay(layers.opaque, view.widget) }
    }

    private func setContent(_ widget: GTKWidget?) {
        gtk_overlay_set_child(layers.opaque, widget)
        if widget != nil, !isHidden { firstPresent() }
    }

    /// Shows the window the first time it has something to show and its scene shows it.
    private func firstPresent() {
        guard !presented else { return }
        presented = true
        present()
    }

    /// Brings the window forward.
    func present() {
        gtk_window_present(widget.of(GtkWindow.self))
    }

    /// Closes the window as the tree or the host does: nobody hears it as the user's.
    func close() {
        isClosed = true
        gtk_window_close(widget.of(GtkWindow.self))
    }

    /// The window went - the user closed it: it closes nothing more.
    func closed() {
        isClosed = true
    }
}
