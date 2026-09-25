// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A `GtkButton`: its caption and how it looks, whether it takes a press, and the click it raises.
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

    /// How the caption's words look.
    private(set) var look = GTKTextLook()

    /// The style sheet's class drawing the button's box.
    private var boxClass: String?

    /// The caption.
    func setText(_ text: String) {
        gtk_button_set_label(widget.of(GtkButton.self), text)
        writeLook()
    }

    /// Changes how the caption's words look.
    func setLook(_ change: (inout GTKTextLook) -> Void) {
        change(&look)
        writeLook()
    }

    /// Writes the look on the label the button shows its caption in.
    private func writeLook() {
        guard let label = gtk_button_get_child(widget.of(GtkButton.self)),
              g_type_check_instance_is_a(label.of(GTypeInstance.self), gtk_label_get_type()) != 0
        else { return }
        let list = pango_attr_list_new()!
        look.insert(into: list)
        gtk_label_set_attributes(label.opaque, list)
        pango_attr_list_unref(list)
    }

    /// The button's box - its fill, its outline's colour and width, and its shape - as a class of the host's style
    /// sheet; what is nil stays the platform's.
    /// Design: docs/design/platforms/gtk/controls.md#a-buttons-box
    func setBox(fill: HostValue?, stroke: HostValue?, strokeWidth: Double?, shape: HostValue?) {
        let radius: Double? = switch shape.map({ GTKOutline(container: $0) }) {
        case .rounded(let radius)?: radius
        case .ellipse?: 9999
        case .rectangle?: 0
        case nil: nil
        }
        let drawn = GTKStyleSheet.box(
            fill: fill.flatMap { GTKBrush($0).firstColor }, stroke: stroke.flatMap { GTKBrush($0).firstColor },
            strokeWidth: stroke == nil ? nil : max(0, strokeWidth ?? 1), radius: radius)
        guard drawn != boxClass else { return }
        if let boxClass { gtk_widget_remove_css_class(widget, boxClass) }
        if let drawn { gtk_widget_add_css_class(widget, drawn) }
        boxClass = drawn
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
