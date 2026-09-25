// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A `GtkButton`: its caption, whether it takes a press, and the click it raises.
@MainActor
final class GTKButtonView: GTKView {
    /// What the button does when the user clicks it.
    var onClicked: (() -> Void)?

    init() {
        super.init { _ in gtk_button_new() }
        connect("clicked") { _, data in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.clicked() }
        }
    }

    /// The caption.
    func setText(_ text: String) {
        gtk_button_set_label(widget.of(GtkButton.self), text)
    }

    /// The caption the button shows now, read back from GTK.
    var text: String {
        gtk_button_get_label(widget.of(GtkButton.self)).map { String(cString: $0) } ?? ""
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        onClicked = nil
    }
}
