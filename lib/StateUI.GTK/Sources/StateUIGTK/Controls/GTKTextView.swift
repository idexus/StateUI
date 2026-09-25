// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A `GtkLabel`: its words, wrapped at the width it is given, from its leading edge.
@MainActor
class GTKTextView: GTKView {
    init() {
        super.init { _ in gtk_label_new(nil) }
        gtk_label_set_wrap(widget.opaque, 1)
        gtk_label_set_wrap_mode(widget.opaque, PANGO_WRAP_WORD_CHAR)
        gtk_label_set_xalign(widget.opaque, 0)
    }

    /// The words shown.
    func setText(_ text: String) {
        gtk_label_set_text(widget.opaque, text)
    }

    /// The words the label shows now, read back from GTK.
    var text: String {
        String(cString: gtk_label_get_text(widget.opaque))
    }
}
