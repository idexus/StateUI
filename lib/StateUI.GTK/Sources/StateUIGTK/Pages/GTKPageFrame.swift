// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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
    private var sidebarButton: GTKButtonView?
    private var overflowButton: GTKWidget?
    fileprivate var overflowPopover: GTKWidget?

    /// The style sheet's class painting the header bar.
    private var barClass: String?
    private(set) var overflowButtons: [GTKButtonView] = []

    init(page: GTKView) {
        self.page = page
        widget = adw_toolbar_view_new()!
        g_object_ref_sink(widget)
        header = adw_header_bar_new()!
        // Held by the frame too: a title view takes its place in the bar, and the bar lets go of it there.
        heading = adw_window_title_new("", nil)!
        g_object_ref_sink(heading)
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
        g_object_unref(heading)
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
        if chrome.barBackground != self.chrome.barBackground || chrome.barForeground != self.chrome.barForeground {
            paintBar(background: chrome.barBackground, foreground: chrome.barForeground)
        }
        showActions(chrome.actions, overflow: chrome.overflow)
        showSidebarButton(chrome.sidebar)
        self.chrome = chrome
    }

    /// Paints the header bar and what stands on it, as a class of the host's style sheet; nil keeps the platform's.
    private func paintBar(background: HostValue?, foreground: HostValue?) {
        let painted = GTKStyleSheet.bar(
            background: GTKBrush(background).firstColor, foreground: foreground.flatMap(GTKBrush.rgba))
        if let barClass { gtk_widget_remove_css_class(header, barClass) }
        if let painted { gtk_widget_add_css_class(header, painted) }
        barClass = painted
    }

    /// The sidebar's toggle at the bar's start, pressed in while the sidebar shows, while the page offers it.
    private func showSidebarButton(_ sidebar: (shows: Bool, toggle: () -> Void)?) {
        guard let sidebar else {
            if let sidebarButton { adw_header_bar_remove(header.opaque, sidebarButton.widget) }
            sidebarButton = nil
            return
        }
        if sidebarButton == nil {
            let button = GTKButtonView(toggles: true)
            gtk_button_set_icon_name(button.widget.of(GtkButton.self), "sidebar-show-symbolic")
            gtk_widget_set_tooltip_text(button.widget, "Toggle Sidebar")
            adw_header_bar_pack_start(header.opaque, button.widget)
            sidebarButton = button
        }
        sidebarButton?.onClicked = sidebar.toggle
        gtk_toggle_button_set_active(sidebarButton?.widget.of(GtkToggleButton.self), sidebar.shows ? 1 : 0)
    }

    /// The sidebar's toggle, where the bar shows one.
    var sidebarToggle: GTKButtonView? { sidebarButton }

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
            let button = GTKButtonView.action(action, inMenu: true)
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
    /// A button performing `action`: on the header bar its picture as an icon, else its title; in the overflow's
    /// menu its title.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    static func action(_ action: GTKToolbarAction, inMenu: Bool = false) -> GTKButtonView {
        let button = GTKButtonView()
        if inMenu || action.icon.map({ button.setIcon($0, size: 16, caption: action.title) }) != true {
            button.setText(action.title)
        }
        button.setEnabled(action.isEnabled)
        button.onClicked = action.perform
        return button
    }
}
