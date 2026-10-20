// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A CheckBox: a `GtkCheckButton`, its words beside its box.
/// Design: docs/design/platforms/gtk/controls.md#on-or-off
@MainActor
final class GTKCheckView: GTKToggleView {
    /// How the words look.
    private(set) var look = TextLook()

    init() {
        let button = gtk_check_button_new()!
        super.init(button, control: button, turning: "active")
    }

    override var isOn: Bool { gtk_check_button_get_active(widget.of(GtkCheckButton.self)) != 0 }

    /// The box while it is ticked.
    override var accent: String? { " > check:checked" }

    override func setOn(_ on: Bool) {
        gtk_check_button_set_active(widget.of(GtkCheckButton.self), on ? 1 : 0)
    }

    /// The words the button shows now, read back from GTK.
    var text: String {
        gtk_check_button_get_label(widget.of(GtkCheckButton.self)).map { String(cString: $0) } ?? ""
    }

    /// The words beside the box, and how they look; empty words show none.
    func setCaption(_ text: String, look: TextLook) {
        self.look = look
        gtk_check_button_set_label(widget.of(GtkCheckButton.self), text.isEmpty ? nil : text)
        var child = gtk_widget_get_first_child(widget)
        while let each = child, g_type_check_instance_is_a(each.of(GTypeInstance.self), gtk_label_get_type()) == 0 {
            child = gtk_widget_get_next_sibling(each)
        }
        guard let label = child else { return }
        let list = pango_attr_list_new()!
        look.insert(into: list)
        gtk_label_set_attributes(label.opaque, list)
        pango_attr_list_unref(list)
    }
}
