// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// One window element shown in a WinUI window: what the host layer says it shows - its arrangement of pages, its
/// sheets, its overlays, its frame and its chrome - turned into WinUI's, in step with the element as the tree changes.
/// Design: docs/design/platforms/winui/runtime.md#the-window
@MainActor
final class WinUIWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    /// The WinUI window it is shown in.
    let window = WinUIWindow()

    /// What the window shows, by the host layer's rule.
    private let presentation = WindowPresentation()

    /// The sheets the window shows, one for each page its views present, the last shown on top.
    private var sheets: [(element: MountedElement, sheet: WinUISheetView)] = []
    var sheetsForTesting: [WinUISheetView] { sheets.map(\.sheet) }
    func sheetForTesting(presenting page: MountedElement) -> WinUISheetView? { sheets.first { $0.element === page }?.sheet }

    /// The page or tab view heading its content with its title, while the chrome names the application in its
    /// place.
    private weak var headed: WinUILayoutView?

    /// Heads `page` - a page, or a tab view naming the window - with its title, and the one headed before it no more.
    /// Design: docs/design/platforms/winui/pages.md#a-pages-heading
    private func head(_ page: MountedElement?) {
        let view = page?.winUI.view as? WinUILayoutView
        if headed !== view { headed?.setHeading(nil) }
        headed = view
        view?.setHeading(page?.value(.title)?.string.flatMap { $0.isEmpty ? nil : $0 })
    }

    init(_ element: MountedElement) {
        self.element = element
        window.useTheme(HostThemes.held)
    }

    /// Shows what the element asks for now. The host layer tells the page the user sees and the window made before
    /// the window is first shown, and so before it hears it came to the front.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        stand(changes)
        // The sidebars over the detail stand on the window's background too; the sheets do as they are shown.
        if changes.traits != nil { for split in element.splitViews { split.winUI.groundSidebar() } }
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.winUI.view) }
        showSheets(presentation.sheets, in: runtime)
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.winUI.view)) }
    }

    /// Stands the window as the element asks: the place, the size, the bounds and the traits the tree changed, and
    /// whether its scene hides it.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-frame
    private func stand(_ changes: WindowPresentation.Changes) {
        if let frame = changes.frame { window.request(frame) }
        if let bounds = changes.bounds { window.bound(bounds) }
        if let traits = changes.traits { window.apply(traits) }
        if let hidden = changes.hidden { window.setHidden(hidden) }
    }

    /// Keeps a sheet for each page presented, in its order, by the host layer's rule (`SheetChange`): a sheet gone
    /// leaves, the top first, and one new comes over those before it - each under its page's title, written again on
    /// every presentation.
    /// Design: docs/design/platforms/winui/pages.md#sheets
    private func showSheets(_ pages: [MountedElement], in runtime: HostRuntime) {
        let change = SheetChange(from: sheets, to: pages) { $0.element === $1 }
        for _ in change.leaving { window.popSheet() }
        sheets.removeLast(sheets.count - change.kept)
        for (page, sheet) in sheets { show(page, on: sheet, in: runtime) }
        for page in change.coming {
            let sheet = WinUISheetView()
            show(page, on: sheet, in: runtime)
            window.pushSheet(sheet)
            sheets.append((page, sheet))
        }
    }

    /// A sheet has no bar of its own: the card shows the head of the one a stack in it brings - the title, the way
    /// back, the page's actions and, where the page offers it, the close button.
    private func show(_ page: MountedElement, on sheet: WinUISheetView, in runtime: HostRuntime) {
        sheet.stand(on: page.overlaidGround)
        let fits = SheetSize.asks(page)
        guard let element, page.bringsABar else {
            return sheet.show(
                title: "", page: page.winUI.view, back: nil, close: nil, words: CoreLink().chromeWords, fits: fits)
        }
        let chrome = WindowChrome(window: element, arrangement: page)
        sheet.show(
            title: chrome.showsTitle ? chrome.title ?? "" : "", page: page.winUI.view,
            back: chrome.back.map { back in
                { [weak element, weak stack = back.stack] in
                    if let element, let stack { runtime.goBack(.pop(stack), in: element) }
                }
            },
            leading: chrome.actions.start.map { $0.map(Self.action) },
            trailing: chrome.actions.end.map { $0.map(Self.action) },
            overflow: chrome.actions.overflow.map(Self.action),
            close: page.offersClose
                ? { [weak element, weak page] in
                    if let element, let page { runtime.goBack(.dismissSheets([page]), in: element) }
                }
                : nil,
            words: CoreLink().chromeWords, fits: fits)
    }

    /// The user took the top sheet away - Escape, its dismissing: the window is told how many remain.
    func dismissTopSheet(in runtime: HostRuntime) {
        guard let element, !presentation.sheets.isEmpty else { return }

        runtime.goBack(.dismissSheets(Array(presentation.sheets.suffix(1))), in: element)
    }

    /// Goes the way back the window offers: the top sheet's, else the arrangement's.
    /// Design: docs/design/host/pages.md#the-way-back
    private func goBack(in runtime: HostRuntime) {
        guard let element, let way = presentation.wayBack else { return }

        runtime.goBack(way, in: element)
    }

    /// Lays the chrome the host layer composes from what the window shows in WinUI's: the title or the title area, the
    /// way back, the page's actions, the title view, the colors, the menus, the sidebar's toggle, a sheet's buttons
    /// and the tabs.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    func refreshChrome(in runtime: HostRuntime) {
        guard let element else { return }

        let composed = WindowChrome(window: element, arrangement: presentation.arrangement)
        var chrome = WinUIWindowChrome()
        chrome.title = composed.title ?? ""
        chrome.titleArea = composed.titleArea
        chrome.showsTitle = composed.showsTitle
        chrome.back = composed.back.map { back in
            WinUIToolbarAction(title: back.title, isEnabled: true, perform: { [weak element, weak stack = back.stack] in
                if let element, let stack { runtime.goBack(.pop(stack), in: element) }
            })
        }
        if composed.showsSidebarToggle, let split = composed.splitView {
            chrome.sidebarToggle = { [weak split] in
                guard let split else { return }
                split.winUI.changeSidebarVisibility(to: !split.sidebarIsVisible)
            }
        }
        chrome.center = composed.center?.winUI.view
        chrome.leading = composed.actions.start.map { $0.map(Self.action) }
        chrome.trailing = composed.actions.end.map { $0.map(Self.action) }
        chrome.overflow = composed.actions.overflow.map(Self.action)
        chrome.background = composed.background
        chrome.foreground = composed.foreground
        // WinUI keeps no Edit menu of its own: one the page joins holds the field's undoing, clipboard and selection.
        chrome.menuBar = WinUIMenu(
            menus: composed.menus.editing(CoreLink().editWords, redo: KeyboardShortcut("y")).menus)
        chrome.takeKey = { [weak self, weak element] pressed in
            guard let self, let element else { return false }
            let holder = KeyPresses.holder(under: element) { held in
                (held.native as? WinUIElement)?.view.map { stateui_winui_focused($0.handle) } ?? false
            }
            return KeyPresses.press(
                pressed.key, modifiers: pressed.modifiers, focused: holder, front: presentation.frontPage, in: runtime)
        }
        chrome.escape = { [weak element] in
            element.map { KeyboardShortcuts.press(KeyboardShortcut(.escape, modifiers: []), under: $0, in: runtime) } ?? false
        }
        let headed = composed.titleArea != nil && composed.showsTitle
        head(headed ? presentation.arrangement?.titledPage : nil)
        if !presentation.sheets.isEmpty {
            chrome.sheet = (
                back: { [weak self] in self?.goBack(in: runtime) },
                dismiss: { [weak self] in self?.dismissTopSheet(in: runtime) })
        }
        window.apply(chrome, tabs: windowTabs)
    }

    /// A page's action as a button of the chrome, read as a menu's entry is (`MenuEntry`).
    private static func action(_ item: MountedElement) -> WinUIToolbarAction {
        let entry = MenuEntry.entry(of: item)
        return WinUIToolbarAction(
            title: entry.title, isEnabled: entry.isEnabled, identifier: entry.identifier,
            icon: WinUIPictures.lines(entry.icon), isDestructive: entry.isDestructive,
            showsWords: item.showsActionWords, shortcut: entry.keyboardShortcut, mount: item.mount,
            perform: { [weak item] in item?.winUI.choose() },
            isOn: item.type == .toolbarToggle ? entry.isOn == true : nil, menu: menu(of: item))
    }

    /// The menu a bar's button opens, read as a button's is (`ButtonMenu`); nil for one holding none.
    private static func menu(of item: MountedElement) -> WinUIToolbarMenu? {
        let opening = ButtonMenu.opening(of: item)
        guard opening != .none else { return nil }
        return WinUIToolbarMenu(
            opening: opening, entries: ButtonMenu.entries(of: item), inOverflow: ButtonMenu.inOverflow(item))
    }

    /// The tabs the window shows - the visible tabbed view's, where its tabs stand in the window and no heading
    /// stands over them - and the split view whose detail they stand across, if any.
    private var windowTabs: WinUIWindowTabs? {
        guard let tabbed = presentation.arrangement?.visibleTabView, tabbed.tabsStandInWindow,
              let tabs = tabbed.winUI.view as? WinUITabView, !tabs.showsOwnRow
        else { return nil }

        return WinUIWindowTabs(
            tabs: tabs.tabs, selected: tabs.shownIndex, select: { [weak tabs] index in tabs?.selectByUser(index) },
            split: tabbed.parent?.enclosing(type: .splitView)?.winUI.view as? WinUISplitView)
    }

    /// The page's corner in the window, in DIPs: where content stands clear of the window's chrome.
    var safeAreaOrigin: Point {
        window.content?.origin ?? Point(x: 0, y: 0)
    }
}
