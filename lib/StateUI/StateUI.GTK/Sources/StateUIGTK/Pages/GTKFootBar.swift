// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bar at its foot (`.toolbar(.bottom)`): GNOME's action bar beneath the page, its leading groups at its
/// start, the rest at its end and a More menu of those placed behind it - its buttons the header bar's.
/// Design: docs/design/platforms/gtk/pages.md#the-bar-at-the-foot
@MainActor
final class GTKFootBar {
    let widget: GTKWidget
    private let start: GTKWidget
    private let end: GTKWidget
    private let more: GTKWidget
    private let moreList: GTKWidget

    /// What it shows, as it was last drawn.
    private(set) var actions = GTKFootActions()

    /// The buttons of the actions on the bar in reading order, its words, and the buttons behind More.
    private(set) var buttons: [GTKButtonView] = []
    private(set) var labels: [GTKBarLabel] = []
    private(set) var overflowButtons: [GTKButtonView] = []

    init() {
        widget = gtk_action_bar_new()!
        g_object_ref_sink(widget)
        start = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12)!
        end = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12)!
        gtk_action_bar_pack_start(widget.opaque, start)
        gtk_action_bar_pack_end(widget.opaque, end)
        // Held of its own: it leaves the end's box each time the bar is drawn again.
        more = gtk_menu_button_new()!
        g_object_ref_sink(more)
        gtk_menu_button_set_icon_name(more.opaque, "view-more-symbolic")
        gtk_widget_set_tooltip_text(more, CoreLink().chromeWords.more)
        moreList = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        let popover = gtk_popover_new()!
        gtk_popover_set_child(popover.of(GtkPopover.self), moreList)
        gtk_menu_button_set_popover(more.opaque, popover)
    }

    isolated deinit {
        g_object_unref(more)
        g_object_unref(widget)
    }

    /// Shows `next`, drawing it again only where it draws otherwise; else takes its actions again.
    func show(_ next: GTKFootActions) {
        defer { actions = next }
        guard !next.draws(like: actions) else {
            for (button, action) in zip(buttons, (next.leading + next.trailing).joined().filter { !$0.isLabel }) {
                button.onClicked = action.perform
            }
            for (button, action) in zip(overflowButtons, next.overflow) { button.onClicked = closing(action) }
            return
        }
        for edge in [start, end] {
            while let child = gtk_widget_get_first_child(edge) { gtk_box_remove(edge.of(GtkBox.self), child) }
        }
        (buttons, labels) = ([], [])
        for (edge, groups) in [(start, next.leading), (end, next.trailing)] {
            for group in groups {
                let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
                for action in group {
                    if action.isLabel {
                        let label = GTKBarLabel(action)
                        gtk_box_append(box.of(GtkBox.self), label.widget)
                        labels.append(label)
                    } else {
                        let button = GTKButtonView.action(action)
                        gtk_box_append(box.of(GtkBox.self), button.widget)
                        buttons.append(button)
                    }
                }
                gtk_box_append(edge.of(GtkBox.self), box)
            }
        }
        while let row = gtk_widget_get_first_child(moreList) { gtk_box_remove(moreList.of(GtkBox.self), row) }
        overflowButtons = next.overflow.map { action in
            let button = GTKButtonView.action(action, inMenu: true)
            button.onClicked = closing(action)
            gtk_box_append(moreList.of(GtkBox.self), button.widget)
            return button
        }
        if !next.overflow.isEmpty { gtk_box_append(end.of(GtkBox.self), more) }
    }

    /// `action`, closing the More menu first.
    private func closing(_ action: GTKToolbarAction) -> () -> Void {
        { [weak self] in
            if let self { gtk_menu_button_popdown(more.opaque) }
            action.perform()
        }
    }

    /// The groups at `edge` - its start or its end - each its items' widgets, in reading order.
    func groupsForTesting(atStart: Bool) -> [[GTKWidget]] {
        var groups: [[GTKWidget]] = []
        var group = gtk_widget_get_first_child(atStart ? start : end)
        while let box = group {
            if box != more {
                var items: [GTKWidget] = []
                var item = gtk_widget_get_first_child(box)
                while let each = item {
                    items.append(each)
                    item = gtk_widget_get_next_sibling(each)
                }
                groups.append(items)
            }
            group = gtk_widget_get_next_sibling(box)
        }
        return groups
    }

    /// The action of the item whose widget is `widget` on the bar; nil for none.
    func action(on widget: GTKWidget) -> GTKToolbarAction? {
        if let label = labels.first(where: { $0.widget == widget }) { return label.action }
        let onBar = (actions.leading + actions.trailing).joined().filter { !$0.isLabel }
        guard let at = buttons.firstIndex(where: { $0.widget == widget }), at < onBar.count else { return nil }
        return onBar[at]
    }
}
