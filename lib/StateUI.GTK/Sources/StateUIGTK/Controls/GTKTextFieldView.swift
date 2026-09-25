// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A TextField: a `GtkEntry`, whose words reach Swift as they change and whose Enter submits.
/// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
@MainActor
final class GTKTextFieldView: GTKView {
    /// What the field does when its words change, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user presses Enter in it.
    var onSubmitted: (() -> Void)?

    init() {
        super.init { _ in gtk_entry_new() }
        connect("changed") { _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKTextFieldView else { return }
                view.onTextChanged?(view.text)
            }
        }
        connect("activate") { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKTextFieldView)?.onSubmitted?() }
        }
    }

    private var editable: OpaquePointer { widget.opaque }

    /// The words the field shows now, read back from GTK.
    var text: String {
        String(cString: gtk_editable_get_text(editable))
    }

    /// Writes the words where they differ from the field's, with the caret after them.
    func setText(_ text: String) {
        guard text != self.text else { return }
        gtk_editable_set_text(editable, text)
        gtk_editable_set_position(editable, -1)
    }

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?) {
        gtk_entry_set_placeholder_text(widget.of(GtkEntry.self), placeholder)
    }

    /// The most characters the field takes; nil for no bound.
    func setMaximumLength(_ length: Int?) {
        gtk_entry_set_max_length(widget.of(GtkEntry.self), Int32(length ?? 0))
    }

    override func detach() {
        onTextChanged = nil
        onSubmitted = nil
    }
}
