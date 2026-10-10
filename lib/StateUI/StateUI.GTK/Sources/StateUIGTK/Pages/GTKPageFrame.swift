// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A page as GNOME's applications stand one: an `AdwToolbarView` whose top bar is the page's own `AdwHeaderBar` -
/// and a tabbed view's tabs in a bar beneath it - over the page's view. In a navigation view the frame slides with its page, header bar and all.
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

    /// The bar's start - the sidebar's toggle, then the leading groups - and its end - the trailing groups, the
    /// overflow's menu, then the main menu.
    private let startBox: GTKWidget
    let endBox: GTKWidget

    /// The groups of actions at each edge, a box each.
    let leadingGroups: GTKWidget
    let trailingGroups: GTKWidget

    /// The actions' buttons on the bar, in reading order: the leading groups', then the trailing groups'.
    private(set) var buttons: [GTKButtonView] = []
    private var sidebarButton: GTKButtonView?
    private var overflowButton: GTKWidget?

    /// The bar's main menu - GNOME's in place of a menu bar - and the menus it holds; nil while the page declares none.
    private(set) var mainMenu: (button: GTKWidget, menu: GTKMenu)?
    fileprivate var overflowPopover: GTKWidget?

    /// The bar beneath the header bar holding a tabbed view's switcher, where the page has one.
    private var tabsBar: GTKWidget?

    /// The style sheet's class painting the header bar, and the tabs' bar with it.
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
        startBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        leadingGroups = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, Self.groupSpacing)!
        gtk_box_append(startBox.of(GtkBox.self), leadingGroups)
        adw_header_bar_pack_start(header.opaque, startBox)
        endBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        trailingGroups = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, Self.groupSpacing)!
        gtk_box_append(endBox.of(GtkBox.self), trailingGroups)
        adw_header_bar_pack_end(header.opaque, endBox)
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

    /// What parts one group of actions from the next: twice the room between two buttons of a group.
    private static let groupSpacing: Int32 = 12

    /// Shows `chrome` on the header bar, writing only what differs from what it shows.
    func show(_ chrome: GTKPageChrome) {
        if chrome.title != self.chrome.title { adw_window_title_set_title(heading.opaque, chrome.title) }
        if chrome.subtitle != self.chrome.subtitle { adw_window_title_set_subtitle(heading.opaque, chrome.subtitle ?? "") }
        if chrome.titleView !== self.chrome.titleView {
            adw_header_bar_set_title_widget(header.opaque, chrome.titleView?.widget ?? heading)
        }
        if chrome.showsBar != self.chrome.showsBar {
            adw_toolbar_view_set_reveal_top_bars(widget.opaque, chrome.showsBar ? 1 : 0)
        }
        if chrome.offersBack != self.chrome.offersBack {
            adw_header_bar_set_show_back_button(header.opaque, chrome.offersBack ? 1 : 0)
        }
        if chrome.tabs !== self.chrome.tabs { showTabs(chrome.tabs) }
        if chrome.barBackground != self.chrome.barBackground || chrome.barForeground != self.chrome.barForeground {
            paintBar(background: chrome.barBackground, foreground: chrome.barForeground)
        }
        showActions(leading: chrome.leading, trailing: chrome.trailing, overflow: chrome.overflow)
        showMainMenu(chrome.mainMenu)
        showSidebarButton(chrome.sidebar)
        self.chrome = chrome
    }

    /// Paints the header bar and what stands on it - in the colour written, else light on a dark band and dark on a
    /// light one (`BandWords`) - as a class of the host's style sheet; nil keeps the platform's.
    private func paintBar(background: HostValue?, foreground: HostValue?) {
        let painted = GTKStyleSheet.bar(
            background: GTKBrush(background).firstColor,
            foreground: BandWords.color(on: background, written: foreground).flatMap(GTKBrush.rgba))
        for bar in [header] + (tabsBar.map { [$0] } ?? []) {
            if let barClass { gtk_widget_remove_css_class(bar, barClass) }
            if let painted { gtk_widget_add_css_class(bar, painted) }
        }
        barClass = painted
    }

    /// The tabs' switcher at the start of a bar of its own beneath the header bar, which scrolls it across where the
    /// page is narrower than its tabs: the header bar keeps its room for the title and the buttons.
    /// Design: docs/design/platforms/gtk/pages.md#tabs
    private func showTabs(_ tabs: GTKView?) {
        if let tabsBar { adw_toolbar_view_remove(widget.opaque, tabsBar) }
        tabsBar = nil
        guard let tabs else { return }

        if let row = gtk_widget_get_parent(tabs.widget),
           g_type_check_instance_is_a(row.of(GTypeInstance.self), gtk_box_get_type()) != 0 {
            gtk_box_remove(row.of(GtkBox.self), tabs.widget)
        }
        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(row, "toolbar")
        gtk_box_append(row.of(GtkBox.self), tabs.widget)
        let bar = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(bar.opaque, GTK_POLICY_AUTOMATIC, GTK_POLICY_NEVER)
        gtk_scrolled_window_set_propagate_natural_height(bar.opaque, 1)
        gtk_scrolled_window_set_child(bar.opaque, row)
        if let barClass { gtk_widget_add_css_class(bar, barClass) }
        adw_toolbar_view_add_top_bar(widget.opaque, bar)
        tabsBar = bar
    }

    /// The sidebar's toggle at the bar's start, pressed in while the sidebar shows, while the page offers it.
    private func showSidebarButton(_ sidebar: (shows: Bool, toggle: () -> Void)?) {
        guard let sidebar else {
            if let sidebarButton { gtk_box_remove(startBox.of(GtkBox.self), sidebarButton.widget) }
            sidebarButton = nil
            return
        }
        if sidebarButton == nil {
            let button = GTKButtonView(toggles: true)
            gtk_button_set_icon_name(button.widget.of(GtkButton.self), "sidebar-show-symbolic")
            gtk_widget_set_tooltip_text(button.widget, "Toggle Sidebar")
            gtk_box_prepend(startBox.of(GtkBox.self), button.widget)
            sidebarButton = button
        }
        sidebarButton?.onClicked = sidebar.toggle
        gtk_toggle_button_set_active(sidebarButton?.widget.of(GtkToggleButton.self), sidebar.shows ? 1 : 0)
    }

    /// The sidebar's toggle, where the bar shows one.
    var sidebarToggle: GTKButtonView? { sidebarButton }

    /// The groups of actions as buttons at each edge, a group a box of its own, and the overflow behind a menu at the
    /// bar's end.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    private func showActions(
        leading: [[GTKToolbarAction]], trailing: [[GTKToolbarAction]], overflow: [GTKToolbarAction]
    ) {
        let drawsLike = { (new: [GTKToolbarAction], old: [GTKToolbarAction]) in
            new.count == old.count && zip(new, old).allSatisfy { $0.draws(like: $1) }
        }
        let groupsLike = { (new: [[GTKToolbarAction]], old: [[GTKToolbarAction]]) in
            new.count == old.count && zip(new, old).allSatisfy(drawsLike)
        }
        let onBar = (leading + trailing).flatMap { $0 }
        guard !groupsLike(leading, chrome.leading) || !groupsLike(trailing, chrome.trailing)
            || !drawsLike(overflow, chrome.overflow)
        else {
            for (button, action) in zip(buttons, onBar) { button.onClicked = action.perform }
            for (button, action) in zip(overflowButtons, overflow) { button.onClicked = closingOverflow(action) }
            return
        }

        for edge in [leadingGroups, trailingGroups] {
            while let group = gtk_widget_get_first_child(edge) { gtk_box_remove(edge.of(GtkBox.self), group) }
        }
        buttons = []
        for (edge, groups) in [(leadingGroups, leading), (trailingGroups, trailing)] {
            for group in groups {
                let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
                for action in group {
                    let button = GTKButtonView.action(action)
                    gtk_box_append(box.of(GtkBox.self), button.widget)
                    buttons.append(button)
                }
                gtk_box_append(edge.of(GtkBox.self), box)
            }
        }
        if let overflowButton { gtk_box_remove(endBox.of(GtkBox.self), overflowButton) }
        overflowButton = nil
        overflowPopover = nil
        overflowButtons = []
        guard !overflow.isEmpty else { return }

        let list = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        let popover = gtk_popover_new()!
        overflowPopover = popover
        overflowButtons = overflow.map { action in
            let button = GTKButtonView.action(action, inMenu: true)
            button.onClicked = closingOverflow(action)
            gtk_box_append(list.of(GtkBox.self), button.widget)
            return button
        }
        gtk_popover_set_child(popover.of(GtkPopover.self), list)
        let menu = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(menu.opaque, "view-more-symbolic")
        gtk_menu_button_set_popover(menu.opaque, popover)
        // Before the main menu, which stands at the very end whichever of them was made last.
        if let mainMenu {
            gtk_box_insert_child_after(endBox.of(GtkBox.self), menu, gtk_widget_get_prev_sibling(mainMenu.button))
        } else {
            gtk_box_append(endBox.of(GtkBox.self), menu)
        }
        overflowButton = menu
    }
}

extension GTKPageFrame {
    /// The menus at the bar's very end, as GNOME's applications hold theirs: a main menu holding each as a submenu.
    /// Design: docs/design/platforms/gtk/pages.md#menus
    private func showMainMenu(_ menu: GTKMenu?) {
        if let mainMenu, let menu, menu.stands(like: mainMenu.menu) { return }
        if let mainMenu { gtk_box_remove(endBox.of(GtkBox.self), mainMenu.button) }
        mainMenu = nil
        guard let menu, !menu.isEmpty else { return }

        let button = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(button.opaque, "open-menu-symbolic")
        gtk_widget_set_tooltip_text(button, "Main Menu")
        gtk_menu_button_set_menu_model(button.opaque, g_menu_model(menu.model))
        gtk_widget_insert_action_group(button, GTKMenu.actionGroup, OpaquePointer(menu.actions))
        gtk_box_append(endBox.of(GtkBox.self), button)
        mainMenu = (button, menu)
    }

    /// `action`, closing the overflow's menu first.
    private func closingOverflow(_ action: GTKToolbarAction) -> () -> Void {
        { [weak self] in
            if let popover = self?.overflowPopover { gtk_popover_popdown(popover.of(GtkPopover.self)) }
            action.perform()
        }
    }
}

extension GTKButtonView {
    /// A button performing `action`: on the header bar its picture as an icon - its title beside it where it says
    /// so - else its title; in the overflow's menu its title, flat; coloured where it destroys something.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    static func action(_ action: GTKToolbarAction, inMenu: Bool = false) -> GTKButtonView {
        let button = GTKButtonView()
        let pictured = !inMenu && action.icon.map {
            button.setIcon($0, size: 16, caption: action.title, showsCaption: action.showsTitle)
        } == true
        if !pictured { button.setText(action.title) }
        button.setEnabled(action.isEnabled)
        if inMenu { gtk_widget_add_css_class(button.widget, "flat") }
        if action.isDestructive {
            gtk_widget_add_css_class(button.widget, "destructive-action")
            if inMenu { gtk_widget_add_css_class(button.widget, GTKStyleSheet.destructiveWords) }
        }
        button.onClicked = action.perform
        return button
    }
}
