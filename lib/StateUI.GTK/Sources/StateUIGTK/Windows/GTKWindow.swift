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

    private var presented = false

    init(application: UnsafeMutablePointer<GtkApplication>) {
        widget = adw_application_window_new(application)!
        g_object_ref(widget)
        gtk_window_set_default_size(widget.of(GtkWindow.self), 560, 440)
        // GNOME's smallest window, which a window that adapts to its width must say.
        gtk_widget_set_size_request(widget, 360, 294)
    }

    isolated deinit {
        gtk_window_destroy(widget.of(GtkWindow.self))
        g_object_unref(widget)
    }

    /// The window's name, to the desktop - its switcher, its dock; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        gtk_window_set_title(widget.of(GtkWindow.self), title)
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

    private func setContent(_ widget: GTKWidget?) {
        adw_application_window_set_content(self.widget.of(AdwApplicationWindow.self), widget)
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
