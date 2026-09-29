// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// What assistive technology meets of the view, in GTK's accessible terms.
extension GTKView {
    /// Puts the element's words on the widget: its label and its hint - its own where nil - its level as a heading,
    /// and whether it is left out.
    /// Design: docs/design/platforms/gtk/controls.md#what-assistive-technology-meets
    func setAccessibility(_ words: AccessibilityWords) {
        accessibility = words
        let accessible = widget.opaque
        // GTK names a view by its own words only in its own role: a heading says them as its label.
        let label = words.label ?? (words.headingLevel > 0 ? shownWords : nil)
        for (property, text) in [(GTK_ACCESSIBLE_PROPERTY_LABEL, label),
                                 (GTK_ACCESSIBLE_PROPERTY_DESCRIPTION, words.hint)] {
            guard let text else {
                gtk_accessible_reset_property(accessible, property)
                continue
            }
            var value = GValue()
            g_value_init(&value, g_type_from_name("gchararray"))
            g_value_set_string(&value, text)
            var properties = [property]
            gtk_accessible_update_property_value(accessible, 1, &properties, &value)
            g_value_unset(&value)
        }

        var states = [GTK_ACCESSIBLE_STATE_HIDDEN]
        if words.presence == .hidden || words.presence == .hiddenWithChildren {
            var hidden = GValue()
            g_value_init(&hidden, g_type_from_name("gboolean"))
            g_value_set_boolean(&hidden, 1)
            gtk_accessible_update_state_value(accessible, 1, &states, &hidden)
            g_value_unset(&hidden)
        } else {
            gtk_accessible_reset_state(accessible, GTK_ACCESSIBLE_STATE_HIDDEN)
        }

        guard words.headingLevel > 0, becomeHeading() else { return }
        var level = GValue()
        g_value_init(&level, g_type_from_name("gint"))
        g_value_set_int(&level, words.headingLevel)
        var properties = [GTK_ACCESSIBLE_PROPERTY_LEVEL]
        gtk_accessible_update_property_value(accessible, 1, &properties, &level)
        g_value_unset(&level)
    }

    /// Names a heading again by the words it shows, where the element gives it no label of its own.
    func shownWordsChanged() {
        guard let accessibility, accessibility.label == nil, accessibility.headingLevel > 0 else { return }
        setAccessibility(accessibility)
    }

    /// Makes the widget a heading while assistive technology has not met it yet, as GTK allows; whether it is one.
    private func becomeHeading() -> Bool {
        if gtk_accessible_get_accessible_role(widget.opaque) == GTK_ACCESSIBLE_ROLE_HEADING { return true }
        guard gtk_widget_get_root(widget) == nil else { return false }
        var role = GValue()
        g_value_init(&role, gtk_accessible_role_get_type())
        g_value_set_enum(&role, Int32(GTK_ACCESSIBLE_ROLE_HEADING.rawValue))
        g_object_set_property(widget.of(GObject.self), "accessible-role", &role)
        g_value_unset(&role)
        return true
    }
}
