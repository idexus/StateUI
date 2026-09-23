// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI

extension AppKitWindowController {
    /// Composes the window's chrome again from what it shows now.
    func refreshChrome() {
        refreshVisiblePageChrome()
    }

    /// Composes the window's one native chrome from the visible arrangement:
    /// the top page names the window, the stack's way back and the page's
    /// actions are toolbar items, a split page adds the sidebar toggle, the
    /// tabs of a tabbed view on the page path stand beneath the toolbar, and
    /// an authored title bar adds its slots and its own title.
    func refreshVisiblePageChrome() {
        guard let node, let window else { return }
        node.pageNode?.markTabsShownByWindow()
        let titleBar = node.children.first { $0.type == .titleBar }
        let page = node.visiblePage
        let titleView = node.visibleTitleView
        let barColor = node.visibleBarBackground ?? titleBar?.color(.background)
        window.title = page?.string(.title) ?? node.string(.title) ?? "StateUI"
        window.subtitle = ""
        // A page's title view stands in for its title, and over a painted band
        // the title stands in the bar's foreground: either way the window
        // keeps its name for the system and hides the one it would draw.
        window.titleVisibility = titleView == nil && barColor == nil ? .visible : .hidden
        let paintedTitle: NSView? = barColor.flatMap { band in
            guard titleView == nil else { return nil }
            bandTitle.stringValue = window.title
            bandTitle.textColor = Self.foreground(
                on: band,
                written: node.visibleBarForeground ?? titleBar?.color(.barForegroundColor))
            bandTitle.sizeToFit()
            return bandTitle
        }

        let actions = node.visibleToolbarActions
        toolbar.apply(AppKitWindowChrome(
            sidebar: node.pageNode?.sidebarController,
            back: node.visibleBackAction,
            title: paintedTitle,
            leading: titleBar?.firstView(in: .leadingContent),
            center: titleBar?.firstView(in: .content) ?? titleView,
            actions: actions.primary,
            overflow: actions.overflow,
            trailing: titleBar?.firstView(in: .trailingContent)))
        synchronizeBar(window, color: barColor, split: node.pageNode?.view as? AppKitSplitView)
        synchronizeTitleAccessory(
            window,
            titleBar: titleBar,
            foreground: barColor.map { band in
                Self.foreground(
                    on: band,
                    written: titleBar?.color(.barForegroundColor) ?? node.visibleBarForeground)
            })
        synchronizeTabRow(window, node.visibleWindowTabs)
        host?.pageMenusChanged(in: self)
    }

    /// A window's tabs stand beneath its toolbar: on macOS 26 and later across
    /// the split view detail the tabbed view stands in, as that column's own
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

    /// An authored title bar's own title stands at the trailing edge of the
    /// window's title bar, where it is text rather than a toolbar control.
    /// What stands on a painted band: the colour written for it, else white on
    /// a dark band and black on a light one.
    private static func foreground(on band: NSColor, written: NSColor?) -> NSColor {
        if let written { return written }
        guard let rgb = band.usingColorSpace(.sRGB) else { return .labelColor }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent
            + 0.0722 * rgb.blueComponent
        return luminance < 0.5 ? .white : .black
    }

    /// A colour written for the bars paints the band the title bar and
    /// toolbar cover over the visible content - a split view's detail, else
    /// the whole window - and the title bar lets it show. With none written,
    /// the band is the system's material.
    ///
    /// The colour is the window's background too: on a Mac the title bar, the
    /// toolbar and the window's background around a floating sidebar are one
    /// surface, so the sidebar stands framed in the bars' colour, its glass
    /// taking a tint of it. With none written the window keeps the system's.
    /// On a translucent window the colour tints the window's material instead:
    /// the band over the page, the margin around the sidebar and what its
    /// glass shows all wear it, the desktop through it, and no pane paints a
    /// band of its own.
    private func synchronizeBar(_ window: NSWindow, color: NSColor?, split: AppKitSplitView?) {
        window.titlebarAppearsTransparent = color != nil
        let background = isTranslucent ? NSColor.clear : (color ?? .windowBackgroundColor)
        if window.backgroundColor != background { window.backgroundColor = background }
        content.barColor = split == nil && !isTranslucent ? color : nil
        content.materialTint = isTranslucent ? color : nil
        split?.setDetailBarColor(isTranslucent ? nil : color)
    }

    /// An authored title bar's own title, at the trailing edge. It takes
    /// `foreground` only over a painted band; on the system's material it
    /// keeps the system's colours, where a written one could vanish.
    private func synchronizeTitleAccessory(
        _ window: NSWindow,
        titleBar: AppKitElement?,
        foreground: NSColor?
    ) {
        let title = titleBar?.string(.title)
        let subtitle = titleBar?.string(.subtitle)
        let icon = titleBar?.image(.icon)
        guard title != nil || subtitle != nil || icon != nil else {
            if let accessory = titleAccessory,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            titleAccessory = nil
            return
        }

        titleCluster.apply(
            title: title ?? "",
            subtitle: subtitle ?? "",
            image: icon,
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
