// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A `GtkButton`: its caption, whether it takes a press, and the click it raises.
@MainActor
final class GTKButtonView: GTKView {
    /// What the button does when the user clicks it.
    var onClicked: (() -> Void)?

    /// A button, or one that stays pressed in while what it turns on is on.
    init(toggles: Bool = false) {
        super.init { _ in toggles ? gtk_toggle_button_new() : gtk_button_new() }
        connect("clicked") { _, data in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.clicked() }
        }
    }

    /// The caption.
    func setText(_ text: String) {
        gtk_button_set_label(widget.of(GtkButton.self), text)
    }

    /// A picture in place of the caption, `size` logical pixels across; the caption stays the button's name to
    /// assistive technology and its tooltip. Whether there was such a picture.
    @discardableResult
    func setIcon(_ name: String, size: Int32, caption: String) -> Bool {
        guard let image = GTKPictures.icon(named: name, size: size) else { return false }
        gtk_button_set_child(widget.of(GtkButton.self), image)
        gtk_widget_add_css_class(widget, "image-button")
        gtk_widget_set_tooltip_text(widget, caption)

        var property = GTK_ACCESSIBLE_PROPERTY_LABEL
        var name = GValue()
        g_value_init(&name, g_type_from_name("gchararray"))
        g_value_set_string(&name, caption)
        gtk_accessible_update_property_value(widget.opaque, 1, &property, &name)
        g_value_unset(&name)
        return true
    }

    /// The caption the button shows now, read back from GTK.
    var text: String {
        gtk_button_get_label(widget.of(GtkButton.self)).map { String(cString: $0) } ?? ""
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        super.detach()
        onClicked = nil
    }
}
