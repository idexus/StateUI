// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A CheckBox - a `GtkCheckButton` with no caption, the box alone - or a RadioButton, one with its caption, drawn as
/// a radio.
/// Design: docs/design/platforms/gtk/controls.md#on-or-off
@MainActor
final class GTKCheckView: GTKToggleView {
    /// A radio button's partner: GTK draws a check button as a radio only in a group, and a group of the button and
    /// one never shown takes no other button's check away - the host does that for the set the tree names.
    private let partner: GTKWidget?

    /// How the caption's words look.
    private(set) var look = TextLook()

    init(radio: Bool) {
        partner = radio ? gtk_check_button_new() : nil
        if let partner { g_object_ref_sink(partner) }
        super.init({ gtk_check_button_new() }, turning: "active")
        if let partner { gtk_check_button_set_group(partner.of(GtkCheckButton.self), widget.of(GtkCheckButton.self)) }
    }

    isolated deinit {
        if let partner {
            gtk_check_button_set_group(partner.of(GtkCheckButton.self), nil)
            g_object_unref(partner)
        }
    }

    override var isOn: Bool { gtk_check_button_get_active(widget.of(GtkCheckButton.self)) != 0 }

    override func setOn(_ on: Bool) {
        gtk_check_button_set_active(widget.of(GtkCheckButton.self), on ? 1 : 0)
    }

    /// The caption the button shows now, read back from GTK.
    var text: String {
        gtk_check_button_get_label(widget.of(GtkCheckButton.self)).map { String(cString: $0) } ?? ""
    }
}

extension GTKCheckView: GTKWordsView {
    /// The caption.
    func setText(_ text: String) {
        gtk_check_button_set_label(widget.of(GtkCheckButton.self), text.isEmpty ? nil : text)
        writeLook()
    }

    /// Changes how the caption's words look.
    func setLook(_ change: (inout TextLook) -> Void) {
        change(&look)
        writeLook()
    }

    /// Writes the look on the label the button shows its caption in.
    private func writeLook() {
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
