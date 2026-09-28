// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// An application window of libadwaita, showing a page in a frame of its own - its header bar the window's title
/// bar - or an arrangement whose pages carry theirs; presented the first time it shows something.
/// Design: docs/design/platforms/gtk/runtime.md#the-window
@MainActor
final class GTKWindow {
    /// The `AdwApplicationWindow`, held until this is released.
    let widget: GTKWidget

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows: a page's, or an arrangement's.
    private(set) var content: GTKView?

    /// The frame a page shown by itself stands in; nil while the window shows an arrangement.
    private(set) var pageFrame: GTKPageFrame?

    /// The layers the window's content and its overlay stand in.
    private let layers: GTKWidget

    /// What the window lays over everything it shows; nil for nothing.
    private(set) var overlay: GTKView?

    private var presented = false

    /// The size and the smallest size last given.
    private var size: (width: Double?, height: Double?) = (nil, nil)
    private var minimumSize: (width: Double?, height: Double?) = (nil, nil)

    init(application: UnsafeMutablePointer<GtkApplication>) {
        widget = adw_application_window_new(application)!
        g_object_ref(widget)
        gtk_window_set_default_size(widget.of(GtkWindow.self), 560, 440)
        // GNOME's smallest window, which a window that adapts to its width must say.
        gtk_widget_set_size_request(widget, 360, 294)
        layers = gtk_overlay_new()!
        g_object_ref_sink(layers)
        adw_application_window_set_content(widget.of(AdwApplicationWindow.self), layers)
    }

    isolated deinit {
        gtk_window_destroy(widget.of(GtkWindow.self))
        g_object_unref(layers)
        g_object_unref(widget)
    }

    /// The window's name, to the desktop - its switcher, its dock; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        gtk_window_set_title(widget.of(GtkWindow.self), title)
    }

    /// The window's size as it opens, where the window element says one; a window already open takes it too.
    func setSize(width: Double?, height: Double?) {
        guard width != size.width || height != size.height else { return }
        size = (width, height)
        var current: (width: Int32, height: Int32) = (0, 0)
        gtk_window_get_default_size(widget.of(GtkWindow.self), &current.width, &current.height)
        gtk_window_set_default_size(
            widget.of(GtkWindow.self), width.map { Int32($0) } ?? current.width, height.map { Int32($0) } ?? current.height)
    }

    /// How small the user may make the window; GNOME's smallest where the element says none.
    func setMinimumSize(width: Double?, height: Double?) {
        guard width != minimumSize.width || height != minimumSize.height else { return }
        minimumSize = (width, height)
        gtk_widget_set_size_request(widget, Int32(width ?? 360), Int32(height ?? 294))
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

    /// Lays `view` over everything the window shows, where the page stands; nil takes it away.
    /// Design: docs/design/platforms/gtk/pages.md#the-windows-overlay
    func showOverlay(_ view: GTKView?) {
        guard view !== overlay else { return }
        if let overlay { gtk_overlay_remove_overlay(layers.opaque, overlay.widget) }
        overlay = view
        if let view { gtk_overlay_add_overlay(layers.opaque, view.widget) }
    }

    private func setContent(_ widget: GTKWidget?) {
        gtk_overlay_set_child(layers.opaque, widget)
        guard widget != nil, !presented else { return }

        presented = true
        present()
    }

    /// Brings the window forward.
    func present() {
        gtk_window_present(widget.of(GtkWindow.self))
    }

    /// Closes the window.
    func close() {
        gtk_window_close(widget.of(GtkWindow.self))
    }
}
