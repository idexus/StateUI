// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitWindowController {
    /// Composes the window's chrome again from what it shows now.
    func refreshChrome() {
        refreshVisiblePageChrome()
    }

    /// Lays the chrome the host layer composes from what the window shows in AppKit's: the title, the toolbar's way
    /// back, the page's actions and title view, the application's title area, the sidebar's toggle, the bars'
    /// colours, the tabs beneath the toolbar and the page's menus.
    /// Design: docs/design/host/pages.md#the-windows-chrome
    func refreshVisiblePageChrome() {
        guard let element, let window else { return }
        let arrangement = presentation.arrangement
        let chrome = WindowChrome(window: element, arrangement: arrangement)
        let titleView = arrangement?.visiblePage?.chromeTitleView?.appKit.view
        let barColor = chrome.background.flatMap(nsColor)
        let foreground = chrome.foreground.flatMap(nsColor)
        window.title = chrome.title ?? "StateUI"
        window.subtitle = ""
        // A page's title view stands in for its title, and over a painted band
        // the title stands in the bar's foreground: either way the window
        // keeps its name for the system and hides the one it would draw.
        window.titleVisibility = titleView == nil && barColor == nil ? .visible : .hidden
        let paintedTitle: NSView? = chrome.background.flatMap { band in
            guard titleView == nil, barColor != nil else { return nil }
            bandTitle.stringValue = window.title
            bandTitle.textColor = Self.foreground(on: band, written: foreground)
            bandTitle.sizeToFit()
            return bandTitle
        }

        let split = chrome.sidebarToggle?.appKit.view as? AppKitSplitView
        toolbar.apply(AppKitWindowChrome(
            sidebar: split?.splitController,
            back: chrome.back.map { back in
                AppKitToolbarAction(
                    identifier: AppKitWindowToolbar.back, title: back.title, image: AppKitWindowToolbar.backImage,
                    isEnabled: true,
                    perform: { [weak host, weak element, weak stack = back.stack] in
                        if let host, let element, let stack { host.runtime.goBack(.pop(stack), in: element) }
                    })
            },
            title: paintedTitle,
            leadingActions: chrome.actions.leading.map { $0.map(Self.action) },
            center: chrome.center?.appKit.view,
            actions: chrome.actions.trailing.map { $0.map(Self.action) },
            overflow: chrome.actions.overflow.map(Self.action)))
        synchronizeBar(window, color: barColor, split: split)
        synchronizeTitleAccessory(
            window,
            area: chrome.titleArea,
            foreground: chrome.background.flatMap { band in
                barColor.map { _ in Self.foreground(on: band, written: foreground) }
            })
        synchronizeTabRow(window, windowTabs(arrangement))
        host?.pageMenusChanged(in: self)
    }

    /// A page's action as a toolbar item.
    private static func action(_ item: MountedElement) -> AppKitToolbarAction {
        AppKitToolbarAction(
            identifier: NSToolbarItem.Identifier("StateUI.action.\(item.mount)"),
            title: item.value(.text)?.string ?? "",
            image: item.appKit.image(.icon),
            isEnabled: item.isEffectivelyEnabled,
            perform: { [weak item] in item?.appKit.clicked(nil) })
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

    /// What stands on a painted band: the colour written for it, else white on
    /// a dark band and black on a light one (`BandWords`).
    /// Design: docs/design/host/layout.md#words-on-a-painted-band
    private static func foreground(on band: HostValue, written: NSColor?) -> NSColor {
        if let written { return written }
        guard let light = BandWords.light(on: band) else { return .labelColor }
        return light ? .white : .black
    }

    /// A colour written for the bars paints the band the title bar and
    /// toolbar cover - the window's, under a floating sidebar's glass, and the
    /// visible content's, a split view's detail - and the title bar lets it
    /// show. With none written, the band is the system's material.
    ///
    /// The window's background is the one written for the window alone - the
    /// bars' colour paints the bars - else the system's. Where it is a blur,
    /// the window keeps no colour: its material, the system's, shows around the
    /// sidebar and under the page, tinted by the blur's tint.
    private func synchronizeBar(_ window: NSWindow, color: NSColor?, split: AppKitSplitView?) {
        window.titlebarAppearsTransparent = color != nil
        let written = traits?.background.paint.flatMap(nsColor)
        let background = backdrop != nil ? NSColor.clear : (written ?? .windowBackgroundColor)
        // A background that lets the desktop through - clear, or a colour with an alpha - asks a window that is not opaque.
        window.isOpaque = backdrop == nil && background.alphaComponent >= 1
        if window.backgroundColor != background { window.backgroundColor = background }
        content.materialTint = backdrop != nil ? written : nil
        content.barColor = color
        split?.setDetailBarColor(color)
    }

    /// The application's title area, at the trailing edge of the window's
    /// title bar, where it is text rather than a toolbar control. It takes
    /// `foreground` only over a painted band; on the system's material it
    /// keeps the system's colours, where a written one could vanish.
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
            image: area.icon.flatMap { host?.image(named: $0) },
            foreground: foreground)
        // AppKit gives a trailing accessory the toolbar row's height and
        // centres it there; only the width is the cluster's own.
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
