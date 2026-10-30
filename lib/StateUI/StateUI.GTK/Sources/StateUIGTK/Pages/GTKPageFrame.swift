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

    /// The widget showing the page's title on the header bar - what a test reads.
    var titleWidget: GTKWidget { heading }

    /// The bar's start - the sidebar's toggle, then the leading groups - and its end - the trailing groups, the
    /// overflow's menu, then the main menu.
    private let startBox: GTKWidget
    let endBox: GTKWidget

    /// The groups of actions at each edge, a box each.
    let leadingGroups: GTKWidget
    let trailingGroups: GTKWidget

    /// The actions' buttons on the bar, in reading order: the leading groups', then the trailing groups'.
    private(set) var buttons: [GTKButtonView] = []

    /// The words on the bar (`ToolbarLabel`), in reading order.
    private(set) var labels: [GTKBarLabel] = []
    private var sidebarButton: GTKButtonView?

    /// The groups of actions in reading order - the leading, then the trailing - each a box on the bar; how many of
    /// them stand there, the first, the rest behind More; and the bar's width they were last stood for.
    /// Design: docs/design/platforms/gtk/pages.md#a-bar-with-no-room
    private var groups: [(box: GTKWidget, actions: [GTKToolbarAction])] = []
    private var standing = 0
    private var fittedWidth: Int32?

    /// The actions placed behind More whatever the room, and the bar's More: hidden while nothing stands behind it.
    private var placed: [GTKToolbarAction] = []
    private let overflowButton: GTKWidget
    private let overflowList: GTKWidget

    /// The bar's main menu - GNOME's in place of a menu bar - and the menus it holds; nil while the page declares none.
    private(set) var mainMenu: (button: GTKWidget, menu: GTKMenu)?
    fileprivate var overflowPopover: GTKWidget?

    /// The bar beneath the header bar holding a tabbed view's switcher, where the page has one.
    private var tabsBar: GTKWidget?

    /// The style sheet's class painting the header bar, and the tabs' bar with it.
    private var barClass: String?

    /// Whether the bar's gradient was painted before the header bar had a size, to be painted again once it has.
    private var paintsAgainWhenSized = false
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
        overflowList = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        let popover = gtk_popover_new()!
        gtk_popover_set_child(popover.of(GtkPopover.self), overflowList)
        overflowPopover = popover
        overflowButton = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(overflowButton.opaque, "view-more-symbolic")
        gtk_widget_set_tooltip_text(overflowButton, CoreLink().chromeWords.more)
        gtk_menu_button_set_popover(overflowButton.opaque, popover)
        gtk_widget_set_visible(overflowButton, 0)
        // Before the main menu, which is appended after it at the very end.
        gtk_box_append(endBox.of(GtkBox.self), overflowButton)
        adw_header_bar_pack_end(header.opaque, endBox)
        adw_toolbar_view_add_top_bar(widget.opaque, header)
        if let previous = gtk_widget_get_parent(page.widget),
           g_type_check_instance_is_a(previous.of(GTypeInstance.self), adw_toolbar_view_get_type()) != 0 {
            adw_toolbar_view_set_content(previous.opaque, nil)
        }
        adw_toolbar_view_set_content(widget.opaque, page.widget)
        Self.standingFrames.append(Standing(self))
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
        if chrome.showsTitle != self.chrome.showsTitle { gtk_widget_set_visible(heading, chrome.showsTitle ? 1 : 0) }
        if chrome.titleView !== self.chrome.titleView {
            adw_header_bar_set_title_widget(header.opaque, chrome.titleView?.widget ?? heading)
        }
        if chrome.showsBar != self.chrome.showsBar {
            adw_toolbar_view_set_reveal_top_bars(widget.opaque, chrome.showsBar ? 1 : 0)
        }
        if chrome.offersBack != self.chrome.offersBack {
            adw_header_bar_set_show_back_button(header.opaque, chrome.offersBack ? 1 : 0)
        }
        if chrome.offersClose != self.chrome.offersClose {
            adw_header_bar_set_show_end_title_buttons(header.opaque, chrome.offersClose ? 1 : 0)
        }
        if chrome.tabs !== self.chrome.tabs { showTabs(chrome.tabs) }
        if chrome.bottomBar !== self.chrome.bottomBar { showBottomBar(chrome.bottomBar) }
        showFoot(chrome.foot)
        showBottomEdge(
            chrome.bottomBar == nil && chrome.foot.isEmpty ? nil : chrome.bottomBarEdge, following: chrome.bottomBarScroller)
        if chrome.barBackground != self.chrome.barBackground || chrome.barForeground != self.chrome.barForeground {
            paintBar(background: chrome.barBackground, foreground: chrome.barForeground)
        }
        showActions(leading: chrome.leading, trailing: chrome.trailing, overflow: chrome.overflow)
        showMainMenu(chrome.mainMenu)
        showSidebarButton(chrome.sidebar)
        self.chrome = chrome
    }

    /// Paints the header bar and what stands on it - a color or a gradient, its words in the color written, else
    /// light on a dark band and dark on a light one (`BandWords`) - as a class of the host's style sheet; nil keeps
    /// the platform's. A gradient is drawn for the header bar's size as it stands, again once it has one.
    /// Design: docs/design/platforms/gtk/pages.md#the-bars-look
    private func paintBar(background: HostValue?, foreground: HostValue?) {
        let size = (width: Double(gtk_widget_get_width(header)), height: Double(gtk_widget_get_height(header)))
        paintsAgainWhenSized = HostBrush(background).isGradient && (size.width <= 0 || size.height <= 0)
        let painted = GTKStyleSheet.bar(
            background: background, over: size,
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

    /// The holder of the page's bottom bar beneath its content; nil until the page shows one or a bar at its foot.
    private var bottomHolder: GTKWidget?

    /// The page's bar at its foot, beneath its bottom bar; nil until the page shows one.
    private(set) var footBar: GTKFootBar?

    /// The holder of the bottom bar, made with the bar at the foot beneath it: the toolbar view stands its bottom bars
    /// in the order they came.
    private func holder() -> GTKWidget {
        if let bottomHolder { return bottomHolder }
        let made = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_visible(made, 0)
        adw_toolbar_view_add_bottom_bar(widget.opaque, made)
        bottomHolder = made
        let foot = GTKFootBar()
        gtk_widget_set_visible(foot.widget, 0)
        adw_toolbar_view_add_bottom_bar(widget.opaque, foot.widget)
        footBar = foot
        return made
    }

    /// Shows `actions` on the bar at the page's foot, beneath its bottom bar; none hides it.
    /// Design: docs/design/platforms/gtk/pages.md#the-bar-at-the-foot
    private func showFoot(_ actions: GTKFootActions) {
        guard !actions.isEmpty || footBar != nil else { return }
        _ = holder()
        footBar?.show(actions)
        if let footBar { gtk_widget_set_visible(footBar.widget, actions.isEmpty ? 0 : 1) }
    }

    /// The page's bottom bar beneath its content, as GNOME's applications stand theirs: beside the content, which
    /// ends above it - in a holder of the frame's own, taken from another frame's where it stood there.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    private func showBottomBar(_ bar: GTKView?) {
        if let shown = chrome.bottomBar, let holder = bottomHolder, gtk_widget_get_parent(shown.widget) == holder {
            gtk_box_remove(holder.of(GtkBox.self), shown.widget)
        }
        guard let bar else {
            if let bottomHolder { gtk_widget_set_visible(bottomHolder, 0) }
            return
        }
        if let row = gtk_widget_get_parent(bar.widget),
           g_type_check_instance_is_a(row.of(GTypeInstance.self), gtk_box_get_type()) != 0 {
            gtk_box_remove(row.of(GtkBox.self), bar.widget)
        }
        let holder = holder()
        gtk_box_append(holder.of(GtkBox.self), bar.widget)
        gtk_widget_set_visible(holder, 1)
    }

    /// The bottom bar's edge, GNOME's own: its flat bar, which shows its shadow while the content scrolls, for the
    /// platform's; a border on its own ground while `scroller`'s rows go on past it, for a hard one. GNOME's flat bar
    /// shows its shadow whatever the edge says.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    private func showBottomEdge(_ edge: ScrollEdge?, following scroller: GTKScrollView?) {
        (page as? GTKSingleChildView)?.bottomBarEdge = edge
        let show: () -> Void = { [weak self, weak scroller] in
            guard let self else { return }
            let hard = edge == .hard && BottomBarPlace.continues(scroller: scroller?.standing)
            adw_toolbar_view_set_bottom_bar_style(widget.opaque, hard ? ADW_TOOLBAR_RAISED_BORDER : ADW_TOOLBAR_FLAT)
        }
        scroller?.standingChanged = show
        show()
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
            gtk_widget_set_tooltip_text(button.widget, CoreLink().chromeWords.sidebar)
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
            for (button, action) in zip(buttons, onBar.filter { !$0.isLabel }) { button.onClicked = action.perform }
            groups = zip(groups, leading + trailing).map { (box: $0.box, actions: $1) }
            placed = overflow
            for (button, action) in zip(overflowButtons, behind.joined()) { button.onClicked = closingOverflow(action) }
            return
        }

        for edge in [leadingGroups, trailingGroups] {
            while let group = gtk_widget_get_first_child(edge) { gtk_box_remove(edge.of(GtkBox.self), group) }
        }
        (buttons, labels) = ([], [])
        groups = []
        for (edge, edgeGroups) in [(leadingGroups, leading), (trailingGroups, trailing)] {
            for group in edgeGroups {
                let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
                for action in group {
                    // Words stand on the bar as a label; an action as its button.
                    if action.isLabel {
                        let label = GTKBarLabel(action)
                        gtk_box_append(box.of(GtkBox.self), label.widget)
                        labels.append(label)
                        continue
                    }
                    let button = GTKButtonView.action(action)
                    gtk_box_append(box.of(GtkBox.self), button.widget)
                    buttons.append(button)
                }
                gtk_box_append(edge.of(GtkBox.self), box)
                groups.append((box, group))
            }
        }
        placed = overflow
        standing = groups.count
        fittedWidth = nil
        showOverflow()
        fit()
    }

    /// The groups that left the bar, each apart, then the actions placed behind More whatever the room.
    private var behind: [[GTKToolbarAction]] {
        BarFit.groupsBehind(left: groups.dropFirst(standing).map(\.actions), placed: placed)
    }

    /// Fills the bar's More with what stands behind it, a line between one group and the next, and shows it while
    /// anything does.
    private func showOverflow() {
        while let row = gtk_widget_get_first_child(overflowList) { gtk_box_remove(overflowList.of(GtkBox.self), row) }
        overflowButtons = []
        for (index, group) in behind.enumerated() {
            if index > 0 { gtk_box_append(overflowList.of(GtkBox.self), gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)) }
            for action in group {
                let button = GTKButtonView.action(action, inMenu: true)
                button.onClicked = closingOverflow(action)
                gtk_box_append(overflowList.of(GtkBox.self), button.widget)
                overflowButtons.append(button)
            }
        }
        stand(standing)
    }

    /// Stands as many groups on the bar as fit in the width it was given, the first in reading order, the rest
    /// behind More (`BarFit`) - again only when that width or the groups changed.
    /// Design: docs/design/platforms/gtk/pages.md#a-bar-with-no-room
    func fit() {
        if paintsAgainWhenSized, gtk_widget_get_width(header) > 0 {
            paintBar(background: chrome.barBackground, foreground: chrome.barForeground)
        }
        let width = room
        guard width > 0, width != fittedWidth else { return }
        fittedWidth = width
        let fitting = BarFit.standing(groups: groups.count) { trial in
            stand(trial.groups)
            var least: Int32 = 0
            var natural: Int32 = 0
            gtk_widget_measure(header, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
            return (trial.title == .centered ? natural : least) <= width
        }
        guard fitting.groups != standing else { return stand(standing) }
        standing = fitting.groups
        showOverflow()
    }

    /// The room the bar has: its width, but no further than any widget around it reaches - a breakpoint lets the
    /// window stand narrower than the bar asks, and the bar, given what it asks, runs past the edge unseen.
    private var room: Int32 {
        var room = gtk_widget_get_width(header)
        var around = gtk_widget_get_parent(header)
        while let each = around {
            var from = graphene_point_t(x: 0, y: 0)
            var to = graphene_point_t(x: 0, y: 0)
            if gtk_widget_compute_point(header, each, &from, &to) != 0 {
                room = min(room, gtk_widget_get_width(each) - Int32(to.x.rounded(.up)))
            }
            around = gtk_widget_get_parent(each)
        }
        return room
    }

    /// The first `count` groups shown on the bar, and its More while anything stands behind it.
    private func stand(_ count: Int) {
        for (index, group) in groups.enumerated() { gtk_widget_set_visible(group.box, index < count ? 1 : 0) }
        gtk_widget_set_visible(overflowButton, count < groups.count || !placed.isEmpty ? 1 : 0)
    }

    /// Every frame standing, held weakly: a window laid out at a new size has each stand its bar again.
    private static var standingFrames: [Standing] = []

    /// Stands every frame's bar for the room it was given, after a window's layout.
    static func fitBars() {
        standingFrames.removeAll { $0.frame == nil }
        for each in standingFrames { each.frame?.fit() }
    }

    /// A frame, held weakly.
    private struct Standing {
        weak var frame: GTKPageFrame?
        init(_ frame: GTKPageFrame) { self.frame = frame }
    }
}

extension GTKPageFrame {
    /// The menus at the bar's very end, as GNOME's applications hold theirs: a main menu holding each as a submenu.
    /// Design: docs/design/platforms/gtk/pages.md#menus
    private func showMainMenu(_ entries: [MenuEntry]) {
        let menu = entries.isEmpty ? nil : GTKMenu(entries, at: .main)
        if let mainMenu, let menu, menu.stands(like: mainMenu.menu) { return }
        if let mainMenu { gtk_box_remove(endBox.of(GtkBox.self), mainMenu.button) }
        mainMenu = nil
        guard let menu, !menu.isEmpty else { return }

        let button = gtk_menu_button_new()!
        gtk_menu_button_set_icon_name(button.opaque, "open-menu-symbolic")
        gtk_widget_set_tooltip_text(button, CoreLink().chromeWords.mainMenu)
        gtk_menu_button_set_menu_model(button.opaque, g_menu_model(menu.model))
        gtk_widget_insert_action_group(button, menu.group, OpaquePointer(menu.actions))
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
    /// so - else its title; in the overflow's menu its title, flat; colored where it destroys something; a setting's
    /// a toggle button, pressed in while on; one holding a menu, the button a button's menu makes - in the overflow's
    /// menu a menu button opening what it offers there.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    static func action(_ action: GTKToolbarAction, inMenu: Bool = false) -> GTKButtonView {
        let opening = action.menu.map { inMenu ? .click : $0.opening } ?? .none
        let button = GTKButtonView(toggles: action.isOn != nil, menu: opening)
        if let menu = action.menu {
            button.setMenu(GTKMenu(inMenu ? menu.inOverflow : menu.entries, at: .button))
            button.showsArrow = inMenu || menu.showsArrow
        }
        if let isOn = action.isOn { gtk_toggle_button_set_active(button.widget.of(GtkToggleButton.self), isOn ? 1 : 0) }
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
