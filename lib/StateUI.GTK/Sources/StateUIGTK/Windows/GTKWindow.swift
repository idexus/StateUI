// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// An application window of libadwaita: a header bar over the page it shows, presented the first time it has one.
/// Design: docs/design/platforms/gtk/runtime.md#the-window
@MainActor
final class GTKWindow {
    /// The `AdwApplicationWindow`, held until this is released.
    let widget: GTKWidget

    /// The toolbar view: the header bar on top, the page beneath it.
    private let toolbar: GTKWidget

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows.
    private(set) var content: GTKView?

    private var presented = false

    init(application: UnsafeMutablePointer<GtkApplication>) {
        widget = adw_application_window_new(application)!
        g_object_ref(widget)
        toolbar = adw_toolbar_view_new()!
        adw_toolbar_view_add_top_bar(toolbar.opaque, adw_header_bar_new())
        adw_application_window_set_content(widget.of(AdwApplicationWindow.self), toolbar)
        gtk_window_set_default_size(widget.of(GtkWindow.self), 560, 440)
    }

    isolated deinit {
        gtk_window_destroy(widget.of(GtkWindow.self))
        g_object_unref(widget)
    }

    /// The header bar's words; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        gtk_window_set_title(widget.of(GtkWindow.self), title)
    }

    /// Shows `view` beneath the header bar - the first one presents the window.
    func show(_ view: GTKView?) {
        content = view
        adw_toolbar_view_set_content(toolbar.opaque, view?.widget)
        guard view != nil, !presented else { return }

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
