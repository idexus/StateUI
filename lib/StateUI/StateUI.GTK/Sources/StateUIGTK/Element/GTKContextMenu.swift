// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A view's context menu: GTK's `GtkPopoverMenu` on the view's widget, its items the menu's actions, opened where
/// the user clicks with the secondary button or holds a finger.
/// Design: docs/design/platforms/gtk/pages.md#menus
@MainActor
final class GTKContextMenu {
    /// The menu the popover shows now.
    private(set) var menu: GTKMenu

    /// The popover, a child of the view's widget.
    let popover: GTKWidget

    private let widget: GTKWidget
    private let number: Int64
    private var controllers: [OpaquePointer] = []
    private static let shown = Numbered<GTKContextMenu>()

    /// How many menus stand on widgets now - what a test counts to see every one let go.
    static var shownCount: Int { shown.count }

    /// `menu` on `widget`, which it opens over - held by a mouse too where `heldByMouse`, a held button's menu.
    init(_ menu: GTKMenu, on widget: GTKWidget, heldByMouse: Bool = false) {
        self.menu = menu
        self.widget = widget
        number = Self.shown.reserve()
        popover = gtk_popover_menu_new_from_model(g_menu_model(menu.model))!
        gtk_widget_set_parent(popover, widget)
        gtk_popover_set_has_arrow(popover.of(GtkPopover.self), 0)
        gtk_widget_set_halign(popover, GTK_ALIGN_START)
        gtk_widget_insert_action_group(widget, menu.group, OpaquePointer(menu.actions))
        Self.shown.hold(self, as: number)
        listen(heldByMouse: heldByMouse)
    }

    /// Shows `menu` in place of the one shown.
    func show(_ menu: GTKMenu) {
        self.menu = menu
        gtk_popover_menu_set_menu_model(popover.opaque, g_menu_model(menu.model))
        gtk_widget_insert_action_group(widget, menu.group, OpaquePointer(menu.actions))
    }

    /// Opens the menu at `x`, `y` in the widget.
    func open(atX x: Double, y: Double) {
        var place = GdkRectangle(x: Int32(x), y: Int32(y), width: 1, height: 1)
        gtk_popover_set_pointing_to(popover.of(GtkPopover.self), &place)
        gtk_popover_popup(popover.of(GtkPopover.self))
        gtk_popover_present(popover.of(GtkPopover.self))
    }

    /// Takes the menu off the widget: its popover, its actions and what opened it.
    func remove() {
        for controller in controllers { gtk_widget_remove_controller(widget, controller) }
        controllers = []
        gtk_widget_insert_action_group(widget, menu.group, nil)
        gtk_widget_unparent(popover)
        Self.shown.release(number)
    }

    /// The secondary button's click and a held finger - a held mouse too, where `heldByMouse` - open the menu where
    /// they are; a hold claims the press, so the button under it is not clicked.
    private func listen(heldByMouse: Bool) {
        let click = gtk_gesture_click_new()!
        gtk_gesture_single_set_button(click, guint(GDK_BUTTON_SECONDARY))
        connectSignal(UnsafeMutableRawPointer(click), "pressed", number: number) { _, _, x, y, data in
            MainActor.assumeIsolated { GTKContextMenu.shown.find(viewNumber(data))?.open(atX: x, y: y) }
        }
        let hold = gtk_gesture_long_press_new()!
        gtk_gesture_single_set_touch_only(hold, heldByMouse ? 0 : 1)
        connectSignal(UnsafeMutableRawPointer(hold), "pressed", number: number) { gesture, x, y, data in
            _ = gtk_gesture_set_state(OpaquePointer(gesture), GTK_EVENT_SEQUENCE_CLAIMED)
            MainActor.assumeIsolated { GTKContextMenu.shown.find(viewNumber(data))?.open(atX: x, y: y) }
        }
        for controller in [click, hold] {
            gtk_widget_add_controller(widget, controller)
            controllers.append(controller)
        }
    }
}
