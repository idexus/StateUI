// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One window element shown in a WinUI window: what the host layer says it shows - its arrangement of pages, its
/// sheets, its overlay, its frame and its chrome - turned into WinUI's, in step with the element as the tree changes.
/// Design: docs/design/platforms/winui/runtime.md#the-window
@MainActor
final class WinUIWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    /// The WinUI window it is shown in.
    let window = WinUIWindow()

    /// What the window shows, by the host layer's rule.
    private let presentation = WindowPresentation()

    /// The sheets the window shows, one for each page its modal stack presents, the last on top.
    private var sheets: [(element: MountedElement, sheet: WinUISheetView)] = []

    init(_ element: MountedElement) {
        self.element = element
    }

    /// Shows what the element asks for now. The host layer tells the page the user sees and the window made before
    /// the window is first shown, and so before it hears it came to the front.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element)
        stand(changes)
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.winUI.view) }
        showSheets(presentation.sheets)
        if let overlay = changes.overlay { window.showOverlay(overlay?.winUI.view) }
    }

    /// Stands the window as the element asks: the place, the size, the bounds and the traits the tree changed.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-frame
    private func stand(_ changes: WindowPresentation.Changes) {
        if let frame = changes.frame { window.request(frame) }
        if let bounds = changes.bounds { window.bound(bounds) }
        if let traits = changes.traits { window.apply(traits) }
    }

    /// Keeps a sheet for each page shown as one, in its order, each under its page's title.
    /// Design: docs/design/platforms/winui/pages.md#the-modal-stack
    private func showSheets(_ pages: [MountedElement]) {
        guard !pages.isEmpty || !sheets.isEmpty else { return }

        sheets = pages.map { page in
            let sheet = sheets.first { $0.element === page }?.sheet ?? WinUISheetView()
            sheet.show(title: page.visiblePage?.value(.title)?.string ?? "", page: page.winUI.view)
            return (page, sheet)
        }
        window.showSheets(sheets.map(\.sheet))
    }

    /// The user took the top sheet away - Escape, its dismissing: the window is told how many remain.
    func dismissTopSheet(in runtime: HostRuntime) {
        guard let element, !presentation.sheets.isEmpty else { return }

        runtime.goBack(.dismissSheet(remaining: presentation.sheets.count - 1), in: element)
    }

    /// Goes the way back the window offers: the top sheet's, else the arrangement's.
    /// Design: docs/design/host/pages.md#the-way-back
    private func goBack(in runtime: HostRuntime) {
        guard let element, let way = presentation.wayBack else { return }

        runtime.goBack(way, in: element)
    }

    /// Lays the chrome the host layer composes from what the window shows in WinUI's: the title, the way back, the
    /// page's actions, the slots, the colours, the menus, the sidebar's toggle, a sheet's buttons and the tabs.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    func refreshChrome(in runtime: HostRuntime) {
        guard let element else { return }

        let composed = WindowChrome(window: element, arrangement: presentation.arrangement)
        var chrome = WinUIWindowChrome()
        chrome.title = composed.title ?? ""
        chrome.back = composed.back.map { back in
            WinUIToolbarAction(title: back.title, isEnabled: true, perform: { [weak element, weak stack = back.stack] in
                if let element, let stack { runtime.goBack(.pop(stack), in: element) }
            })
        }
        chrome.sidebarToggle = composed.sidebarToggle.map { split in
            { [weak split] in
                guard let split else { return }
                split.winUI.changeSidebarVisibility(to: !split.sidebarIsVisible)
            }
        }
        chrome.leading = composed.leading?.winUI.view
        chrome.center = composed.center?.winUI.view
        chrome.trailing = composed.trailing?.winUI.view
        chrome.actions = composed.primaryActions.map(Self.action)
        chrome.overflow = composed.overflowActions.map(Self.action)
        chrome.background = composed.background
        chrome.foreground = composed.foreground
        chrome.menuBar = WinUIMenu(bar: composed.menuBar?.winUI)
        if !presentation.sheets.isEmpty {
            chrome.sheet = (
                back: { [weak self] in self?.goBack(in: runtime) },
                dismiss: { [weak self] in self?.dismissTopSheet(in: runtime) })
        }
        window.apply(chrome, tabs: windowTabs)
    }

    /// A page's action as a button of the chrome.
    private static func action(_ item: MountedElement) -> WinUIToolbarAction {
        WinUIToolbarAction(
            title: item.value(.text)?.string ?? "", isEnabled: item.value(.isEnabled)?.bool ?? true,
            identifier: item.value(.accessibilityIdentifier)?.string,
            perform: { [weak item] in item?.winUI.send(.clicked, []) })
    }

    /// The tabs the window shows - the visible tabbed view's, where its tabs stand in the window - and the split view
    /// whose detail they stand across, if any.
    private var windowTabs: WinUIWindowTabs? {
        guard let tabbed = presentation.arrangement?.visibleTabbedView, tabbed.tabsStandInWindow,
              let tabs = tabbed.winUI.view as? WinUITabbedView
        else { return nil }

        return WinUIWindowTabs(
            titles: tabs.titles, selected: tabs.shownIndex, select: { [weak tabs] index in tabs?.selectByUser(index) },
            split: tabbed.parent?.enclosing(type: .splitView)?.winUI.view as? WinUISplitView)
    }

    /// The page's corner in the window, in DIPs: where content stands clear of the window's chrome.
    var safeAreaOrigin: Point {
        window.content?.origin ?? Point(x: 0, y: 0)
    }
}
