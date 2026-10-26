// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitWindowController {
    /// Composes the window's chrome again from what it shows now, the page's menus with it.
    func refreshChrome() {
        refreshVisiblePageChrome()
        host?.pageMenusChanged(in: self)
    }

    /// Lays the chrome the host layer composes from what the window shows in AppKit's: the title, the toolbar's way
    /// back, the page's actions and title view, the application's title area, the sidebar's toggle, the bars'
    /// colors and the tabs beneath the toolbar.
    /// Design: docs/design/host/pages.md#the-windows-chrome
    func refreshVisiblePageChrome() {
        guard let element, let window else { return }
        let arrangement = presentation.arrangement
        let chrome = WindowChrome(window: element, arrangement: arrangement)
        let titleView = arrangement?.visiblePage?.chromeTitleView?.appKit.view
        let barColor = chrome.background.flatMap(nsColor)
        let foreground = chrome.foreground.flatMap(nsColor)
        window.title = chrome.title ?? element.appKit.core.applicationName
        window.subtitle = chrome.subtitle ?? ""
        // A page's title view stands in for its title, over a painted band the
        // title stands in the bar's foreground, and a page may show none:
        // the window keeps its name for the system and hides the one it would
        // draw.
        window.titleVisibility = titleView == nil && barColor == nil && chrome.showsTitle ? .visible : .hidden
        let paintedTitle: NSView? = chrome.background.flatMap { band in
            guard titleView == nil, barColor != nil, chrome.showsTitle else { return nil }
            bandTitle.stringValue = window.title
            bandTitle.textColor = Self.foreground(on: band, written: foreground)
            bandTitle.sizeToFit()
            return bandTitle
        }

        let split = chrome.splitView?.appKit.view as? AppKitSplitView
        let words = element.appKit.core.chromeWords
        toolbar.apply(AppKitWindowChrome(
            sidebar: split?.splitController,
            showsSidebarToggle: chrome.showsSidebarToggle,
            sidebarLeadingActions: chrome.sidebarActions.start.map { $0.map(Self.action) },
            sidebarActions: chrome.sidebarActions.end.map { $0.map(Self.action) },
            sidebarOverflow: chrome.sidebarActions.overflow.map(Self.action),
            back: chrome.back.map { back in
                AppKitToolbarAction(
                    identifier: AppKitWindowToolbar.back, title: back.title,
                    image: AppKitWindowToolbar.backImage(saying: words.back),
                    isEnabled: true,
                    perform: { [weak host, weak element, weak stack = back.stack] in
                        if let host, let element, let stack { host.runtime.goBack(.pop(stack), in: element) }
                    })
            },
            title: paintedTitle,
            leadingActions: chrome.actions.start.map { $0.map(Self.action) },
            center: chrome.center?.appKit.view,
            actions: chrome.actions.end.map { $0.map(Self.action) },
            overflow: chrome.actions.overflow.map(Self.action),
            words: words))
        split?.onSidebarResized = { [weak self] in self?.toolbar.fitAgain() }
        synchronizeBar(window, color: barColor, split: split)
        // A Mac window names no application of itself: the area says what the sidebar's page says, if anything.
        let area = chrome.splitView?.sidebarPage?.titleArea(applicationName: "")
        synchronizeTitleAccessory(
            window,
            area: area?.isEmpty == false ? area : nil,
            foreground: chrome.background.flatMap { band in
                barColor.map { _ in Self.foreground(on: band, written: foreground) }
            })
        synchronizeTabRow(window, windowTabs(arrangement))
    }

    /// A page's action as a toolbar item.
    static func action(_ item: MountedElement) -> AppKitToolbarAction {
        let isOn = item.type == .toolbarToggle ? item.value(.isOn)?.bool == true : nil
        return AppKitToolbarAction(
            identifier: NSToolbarItem.Identifier("StateUI.action.\(item.mount)"),
            title: item.value(.text)?.string ?? "",
            image: item.itemPicture.flatMap { item.appKit.host?.image($0) },
            isEnabled: item.isEffectivelyEnabled,
            perform: { [weak item] in item?.appKit.clicked(nil) },
            isOn: isOn,
            standsOut: isOn == true && item.value(.onIcon) == nil,
            menu: menu(of: item))
    }

    /// The menu a toolbar's button opens, read as a button's is (`ButtonMenu`); nil for one holding none.
    private static func menu(of item: MountedElement) -> AppKitToolbarMenu? {
        let opening = ButtonMenu.opening(of: item)
        guard opening != .none else { return nil }
        return AppKitToolbarMenu(
            opening: opening, showsArrow: ButtonMenu.showsArrow(item), entries: ButtonMenu.entries(of: item),
            inOverflow: ButtonMenu.inOverflow(item))
    }

    /// The tabs the window shows - the visible tabbed view's, where its tabs stand in the window - and the split view
    /// whose detail they stand across, if any.
    private func windowTabs(_ arrangement: MountedElement?) -> AppKitTabsPlacement? {
        guard let tabbed = arrangement?.visibleTabView, tabbed.tabsStandInWindow,
              let tabs = tabbed.appKit.view as? AppKitTabView
        else { return nil }

        let segments = tabs.segments
        return AppKitTabsPlacement(
            tabs: AppKitWindowTabs(
                titles: segments.map(\.title),
                images: segments.map(\.image),
                selected: tabs.selectedIndex,
                select: { [weak tabs] index in tabs?.selectByUser(index) }),
            split: tabbed.parent?.enclosing(type: .splitView)?.appKit.view as? AppKitSplitView)
    }

    /// The menus of the page the user sees - the top sheet's, else the arrangement's - as the host layer composes
    /// them from its path.
    var pageMenus: [MenuEntry] {
        (presentation.sheets.last ?? presentation.arrangement)?.visiblePage?.chromeMenus.menus ?? []
    }

    /// A window's tabs stand beneath its toolbar: across the split view detail
    /// the tabbed view stands in, where it stands in one, as that column's own
    /// accessory; otherwise as the title bar's bottom accessory.
    private func synchronizeTabRow(_ window: NSWindow, _ placement: AppKitTabsPlacement?) {
        if let placement { tabRow.apply(placement.tabs) }

        let column = placement?.split
        let stays = placement == nil
            ? tabRowAccessory == nil && tabRowSplit == nil
            : column == nil ? tabRowAccessory != nil : column === tabRowSplit
        guard !stays else { return }

        // Out of where it stood before it stands anywhere else: a view has one
        // superview, and taking an accessory away takes its view with it.
        tabRowSplit?.setDetailRow(nil)
        tabRowSplit = nil
        if let accessory = tabRowAccessory,
           let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
            window.removeTitlebarAccessoryViewController(at: index)
        }
        tabRowAccessory = nil

        guard placement != nil else { return }
        if let column {
            tabRow.insets = AppKitTabRow.columnInsets
            column.setDetailRow(tabRow)
            tabRowSplit = column
        } else {
            tabRow.insets = AppKitTabRow.titleBarInsets
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .bottom
            accessory.view = tabRow
            if #available(macOS 26.1, *) { accessory.preferredScrollEdgeEffectStyle = .soft }
            window.addTitlebarAccessoryViewController(accessory)
            tabRowAccessory = accessory
        }
    }

    /// What stands on a painted band: the color written for it, else white on
    /// a dark band and black on a light one (`BandWords`).
    /// Design: docs/design/host/layout.md#words-on-a-painted-band
    private static func foreground(on band: HostValue, written: NSColor?) -> NSColor {
        if let written { return written }
        guard let light = BandWords.light(on: band) else { return .labelColor }
        return light ? .white : .black
    }

    /// A color written for the bars paints the band the title bar and
    /// toolbar cover - the window's, under a floating sidebar's glass, and the
    /// visible content's, a split view's detail - and the title bar lets it
    /// show. With none written, the band is the system's material.
    ///
    /// The window's background is the one written for the window alone - the
    /// bars' color paints the bars - else the system's. Where it is a blur,
    /// the window keeps no color: its material, the system's, shows around the
    /// sidebar and under the page, tinted by the blur's tint.
    private func synchronizeBar(_ window: NSWindow, color: NSColor?, split: AppKitSplitView?) {
        window.titlebarAppearsTransparent = color != nil
        let written = traits?.background.paint.flatMap(nsColor)
        let background = backdrop != nil ? NSColor.clear : (written ?? .windowBackgroundColor)
        // A background that lets the desktop through - clear, or a color with an alpha - asks a window that is not opaque.
        window.isOpaque = backdrop == nil && background.alphaComponent >= 1
        if window.backgroundColor != background { window.backgroundColor = background }
        content.materialTint = backdrop != nil ? written : nil
        content.barColor = color
        split?.setDetailBarColor(color)
    }

    /// The application's title area, at the trailing edge of the window's
    /// title bar, where it is text rather than a toolbar control. It takes
    /// `foreground` only over a painted band; on the system's material it
    /// keeps the system's colors, where a written one could vanish.
    private func synchronizeTitleAccessory(
        _ window: NSWindow,
        area: WindowChrome.TitleArea?,
        foreground: NSColor?
    ) {
        guard let area else {
            if let accessory = titleAccessory,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            titleAccessory = nil
            return
        }

        titleCluster.apply(
            title: area.title ?? "",
            subtitle: area.subtitle ?? "",
            image: area.icon.flatMap { host?.image($0) },
            foreground: foreground)
        // AppKit gives a trailing accessory the toolbar row's height and
        // centers it there; only the width is the cluster's own.
        let fitting = titleCluster.fittingSize
        if titleAccessory != nil {
            if titleCluster.frame.width != fitting.width {
                titleCluster.frame.size.width = fitting.width
            }
        } else {
            titleCluster.frame.size = fitting
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .trailing
            accessory.view = titleCluster
            window.addTitlebarAccessoryViewController(accessory)
            titleAccessory = accessory
        }
    }
}

#endif
