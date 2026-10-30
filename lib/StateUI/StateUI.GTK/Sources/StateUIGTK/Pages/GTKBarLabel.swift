// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A bar's words nobody chooses (`ToolbarLabel`): its picture before its words, dimmed as GNOME dims a secondary
/// label (`dim-label`).
/// Design: docs/design/platforms/gtk/pages.md#the-bar-at-the-foot
@MainActor
struct GTKBarLabel {
    /// The box holding the picture and the words.
    let widget: GTKWidget

    /// The words.
    let words: GTKWidget

    /// The picture; nil for none.
    let picture: GTKWidget?

    /// What it stands for.
    let action: GTKToolbarAction

    init(_ action: GTKToolbarAction) {
        self.action = action
        widget = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        picture = action.icon.flatMap { GTKPictures.icon($0, size: 16) }
        if let picture { gtk_box_append(widget.of(GtkBox.self), picture) }
        words = gtk_label_new(action.title)!
        gtk_widget_add_css_class(words, "dim-label")
        gtk_box_append(widget.of(GtkBox.self), words)
        gtk_widget_set_valign(widget, GTK_ALIGN_CENTER)
    }
}
