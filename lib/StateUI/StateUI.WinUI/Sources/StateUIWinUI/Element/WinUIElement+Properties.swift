// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native element: made, and given the element's properties.
extension WinUIElement {
    /// Gives the view its context menu again once the menu changed or went.
    /// Design: docs/design/platforms/winui/pages.md#menus
    func refreshContextMenu() {
        // A button holding a menu offers that one: the menu's items' actions are the view's.
        let button = (view as? WinUIButtonView).flatMap { $0.opening == .none ? nil : $0 }
        let menu = children.first { $0.type == (button == nil ? .contextMenu : .buttonMenu) }
        guard contextMenuChanged || (hadContextMenu && menu == nil), let view else { return }
        contextMenuChanged = false
        hadContextMenu = menu != nil
        if let button { return button.setMenu(WinUIMenu(entries: ButtonMenu.entries(of: element))) }
        view.setContextMenu(WinUIMenu(menu))
    }

    func makeView() -> WinUIView? {
        if type == .itemsView, let host {
            return WinUIItemsView(cells: ItemsCells(element, in: host.runtime), reducesMotion: { [weak host] in
                host?.runtime.reducesMotion() ?? false
            })
        }
        if element.isDrawnByParent(in: WinUIRegistrations.registry) || element.isViewless { return nil }
        if let registered = WinUIRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) },
            made: element.made
        ) {
            if let scroll = registered as? WinUIScrollView { follow(scroll) }
            return registered
        }
        switch type {
        case .page, .overlay: return WinUISingleChildView()
        case .popover: return WinUIPopoverView()
        case .navigationStack:
            return WinUINavigationView(reducesMotion: { [weak host] in host?.runtime.reducesMotion() ?? false })
        case .splitView: return WinUISplitView()
        case .tabView: return WinUITabView()
        default: return WinUIUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the element - a patch's or a frame's, the program's write either way: its
    /// registration's first, then what every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        // An arrangement's background is its pages': each that says none stands on it.
        for page in element.pagesGroundedAnew(by: changed) {
            (page.native as? WinUIElement)?.applyProperties(changed: [.background])
        }
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        let taken = WinUIRegistrations.registry.apply(changed, to: view, presenting: element)
        if view.replacedNative {
            // Another native element stands in the view's place: it takes every value the element holds.
            view.replacedNative = false
            contextMenuChanged = hadContextMenu
            return applyProperties(changed: Set(element.properties.keys).union(element.driven.keys))
        }

        let own = changed.subtracting(taken)
        for property in own {
            switch property {
            case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
            case .isVisible: view.setShown(isShown)
            case .isEnabled: view.setEnabled(element.presented(.isEnabled)?.bool ?? true)
            // Ignored, the view and all in it are passed over: a click goes to what is under it.
            case .ignoresInput: view.setIgnoresInput(element.bool(.ignoresInput) == true)
            case .tooltip: view.setTooltip(element.string(.tooltip))
            case .background:
                view.setBackground(HostMaterial(element.drawnBackground).painted)
                (parent?.view as? WinUISplitView)?.paintPane()
            default: break
            }
        }
        if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
        if element.changesAccessibility(changed) {
            view.setAccessibility(element.accessibilityWords)
        }
        if let layers = view as? WinUIZStackView { layers.placement = element.placement }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Forgets the sizes kept by this element's layout and every one above it - up to an ItemsView's entry, whose
    /// cell measures it again (`MountedElement.measuredUpward`) - and asks WinUI to measure again.
    /// Design: docs/design/host/layout.md#measured-once
    func invalidateMeasurements() {
        let walk = element.measuredUpward()
        for each in walk.layouts { (each.winUI.view as? WinUILayoutView)?.forgetMeasurements() }
        if let entry = walk.entry { (entry.parent?.winUI.view as? WinUIItemsView)?.remeasure(entry) }
        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// Hands the scroller's reports to this element, and its wish for the display's frames to the renderer.
    private func follow(_ scroll: WinUIScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onRefreshPulled = { [weak self] in self?.pulled() ?? false }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.runtime.frames.serve(scroll, order: scroll.number) }
        }
    }

    /// The view of this element or the nearest one above it.
    var nearestView: WinUIView? {
        view ?? parent?.nearestView
    }
}
