// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A Switch: a `GtkSwitch` and the words it says beside it, in a row - the words at its start, the switch at its
/// end - where a click on the words turns it too.
/// Design: docs/design/platforms/gtk/controls.md#a-switchs-words
@MainActor
final class GTKSwitchView: GTKToggleView {
    /// The words beside the switch.
    let caption: GTKWidget

    /// How the words look.
    private(set) var look = TextLook()

    /// The name the element gives the switch; nil names it by its words.
    var authoredLabel: String? {
        didSet { name() }
    }

    init() {
        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12)!
        let control = gtk_switch_new()!
        caption = gtk_label_new(nil)!
        gtk_label_set_xalign(caption.opaque, 0)
        gtk_label_set_wrap(caption.opaque, 1)
        gtk_widget_set_hexpand(caption, 1)
        gtk_widget_set_visible(caption, 0)
        gtk_widget_set_valign(control, GTK_ALIGN_CENTER)
        gtk_box_append(row.of(GtkBox.self), caption)
        gtk_box_append(row.of(GtkBox.self), control)
        // The words name the switch, which assistive technology meets alone.
        var hidden = GValue()
        g_value_init(&hidden, g_type_from_name("gboolean"))
        g_value_set_boolean(&hidden, 1)
        var states = [GTK_ACCESSIBLE_STATE_HIDDEN]
        gtk_accessible_update_state_value(caption.opaque, 1, &states, &hidden)
        g_value_unset(&hidden)
        super.init(row, control: control, turning: "active")
        let click = gtk_gesture_click_new()!
        connectSignal(UnsafeMutableRawPointer(click), "released", number: number) { (_, _: Int32, _: Double, _: Double, data) in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKSwitchView)?.clickWords() }
        }
        gtk_widget_add_controller(caption, click)
    }

    override var isOn: Bool { gtk_switch_get_active(control.opaque) != 0 }

    /// The track while the switch is on.
    override var accent: String? { " > switch:checked" }

    /// None: GTK paints a switch's box as its track, which a color there would recolor - its register's
    /// `notPlanned`.
    override func setBackground(_ value: HostValue?) {}

    override func setOn(_ on: Bool) {
        gtk_switch_set_active(control.opaque, on ? 1 : 0)
    }

    /// The row, its words and the switch laid out in `direction`: the words at the start whichever side it is.
    override func setDirection(_ direction: GtkTextDirection) {
        super.setDirection(direction)
        gtk_widget_set_direction(caption, direction)
        gtk_widget_set_direction(control, direction)
    }

    /// The words the switch says beside it, read back from GTK.
    var text: String {
        gtk_label_get_text(caption.opaque).map { String(cString: $0) } ?? ""
    }

    /// The words beside the switch, and how they look; empty words show none.
    func setCaption(_ text: String, look: TextLook) {
        self.look = look
        gtk_label_set_text(caption.opaque, text)
        gtk_widget_set_visible(caption, text.isEmpty ? 0 : 1)
        let list = pango_attr_list_new()!
        look.insert(into: list)
        gtk_label_set_attributes(caption.opaque, list)
        pango_attr_list_unref(list)
        name()
    }

    /// Turns the switch as the user's click on its words does.
    func clickWords() {
        guard gtk_widget_is_sensitive(control) != 0 else { return }
        _ = gtk_widget_activate(control)
    }

    /// Names the switch to assistive technology: by the element's label, else by its words.
    private func name() {
        let words = text
        guard let label = authoredLabel ?? (words.isEmpty ? nil : words) else {
            return gtk_accessible_reset_property(control.opaque, GTK_ACCESSIBLE_PROPERTY_LABEL)
        }
        var value = GValue()
        g_value_init(&value, g_type_from_name("gchararray"))
        g_value_set_string(&value, label)
        var properties = [GTK_ACCESSIBLE_PROPERTY_LABEL]
        gtk_accessible_update_property_value(control.opaque, 1, &properties, &value)
        g_value_unset(&value)
    }
}
