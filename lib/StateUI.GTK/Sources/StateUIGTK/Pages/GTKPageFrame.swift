// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A page as GNOME's applications stand one: an `AdwToolbarView` whose top bar is the page's own `AdwHeaderBar`
/// over the page's view. In a navigation view the frame slides with its page, header bar and all.
/// Design: docs/design/platforms/gtk/pages.md#a-page-and-its-header-bar
@MainActor
final class GTKPageFrame {
    /// The toolbar view, held until the frame goes.
    let widget: GTKWidget

    /// The page's view, which the toolbar view shows under its bar.
    let page: GTKView

    /// What the header bar shows now.
    private(set) var chrome = GTKPageChrome()

    let header: GTKWidget
    private let heading: GTKWidget
    private let actionsBox: GTKWidget
    private(set) var buttons: [GTKButtonView] = []
    private var overflowButton: GTKWidget?
    fileprivate var overflowPopover: GTKWidget?
    private(set) var overflowButtons: [GTKButtonView] = []

    init(page: GTKView) {
        self.page = page
        widget = adw_toolbar_view_new()!
        g_object_ref_sink(widget)
        header = adw_header_bar_new()!
        heading = adw_window_title_new("", nil)!
        adw_header_bar_set_title_widget(header.opaque, heading)
        actionsBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        adw_header_bar_pack_end(header.opaque, actionsBox)
        adw_toolbar_view_add_top_bar(widget.opaque, header)
        if let previous = gtk_widget_get_parent(page.widget),
           g_type_check_instance_is_a(previous.of(GTypeInstance.self), adw_toolbar_view_get_type()) != 0 {
            adw_toolbar_view_set_content(previous.opaque, nil)
        }
        adw_toolbar_view_set_content(widget.opaque, page.widget)
    }

    /// Lets go of the toolbar view and nothing in it: a page popped still slides away in it, and GTK lets it go once
    /// the slide is over.
    isolated deinit {
        g_object_unref(widget)
    }

    /// Shows `chrome` on the header bar, writing only what differs from what it shows.
    func show(_ chrome: GTKPageChrome) {
        if chrome.title != self.chrome.title { adw_window_title_set_title(heading.opaque, chrome.title) }
        if chrome.titleView !== self.chrome.titleView {
            adw_header_bar_set_title_widget(header.opaque, chrome.titleView?.widget ?? heading)
        }
        if chrome.showsBar != self.chrome.showsBar {
            adw_toolbar_view_set_reveal_top_bars(widget.opaque, chrome.showsBar ? 1 : 0)
        }
        if chrome.offersBack != self.chrome.offersBack {
            adw_header_bar_set_show_back_button(header.opaque, chrome.offersBack ? 1 : 0)
        }
        showActions(chrome.actions, overflow: chrome.overflow)
        self.chrome = chrome
    }

    /// The page's actions as buttons at the bar's end, in order, and the overflow behind a menu after them.
    private func showActions(_ actions: [GTKToolbarAction], overflow: [GTKToolbarAction]) {
        let same = actions.count == chrome.actions.count && zip(actions, chrome.actions).allSatisfy { $0.draws(like: $1) }
            && overflow.count == chrome.overflow.count && zip(overflow, chrome.overflow).allSatisfy { $0.draws(like: $1) }
        guard !same else {
            for (button, action) in zip(buttons, actions) { button.onClicked = action.perform }
            for (button, action) in zip(overflowButtons, overflow) { button.onClicked = closingOverflow(action) }
            return
        }

        for button in buttons { gtk_box_remove(actionsBox.of(GtkBox.self), button.widget) }
        buttons = actions.map { action in
            let button = GTKButtonView.action(action)
            gtk_box_append(actionsBox.of(GtkBox.self), button.widget)
            return button
        }
        if let overflowButton { gtk_box_remove(actionsBox.of(GtkBox.self), overflowButton) }
        overflowButton = nil
        overflowPopover = nil
        overflowButtons = []
        guard !overflow.isEmpty else { return }

        let list = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        let popover = gtk_popover_new()!
        overflowPopover = popover
        overflowButtons = overflow.map { action in
            let button = GTKButtonView.action(action)
            gtk_widget_add_css_class(button.widget, "flat")
            button.onClicked = closingOverflow(action)
            gtk_box_append(list.of(GtkBox.self), button.widget)
            return button
        }
        gtk_popover_set_child(popover.of(GtkPopover.self), list)
        let menu = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(menu.opaque, "view-more-symbolic")
        gtk_menu_button_set_popover(menu.opaque, popover)
        gtk_box_append(actionsBox.of(GtkBox.self), menu)
        overflowButton = menu
    }
}

extension GTKPageFrame {
    /// `action`, closing the overflow's menu first.
    private func closingOverflow(_ action: GTKToolbarAction) -> () -> Void {
        { [weak self] in
            if let popover = self?.overflowPopover { gtk_popover_popdown(popover.of(GtkPopover.self)) }
            action.perform()
        }
    }
}

extension GTKButtonView {
    /// A button of a header bar performing `action`.
    static func action(_ action: GTKToolbarAction) -> GTKButtonView {
        let button = GTKButtonView()
        button.setText(action.title)
        button.setEnabled(action.isEnabled)
        button.onClicked = action.perform
        return button
    }
}
