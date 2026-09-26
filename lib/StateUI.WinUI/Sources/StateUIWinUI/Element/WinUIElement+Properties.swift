// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native element: made, and given the element's properties.
extension WinUIElement {
    /// Gives the view its context menu again once the menu changed or went.
    /// Design: docs/design/platforms/winui/pages.md#menus
    func refreshContextMenu() {
        let menu = children.first { $0.type == .contextMenu }
        guard contextMenuChanged || (hadContextMenu && menu == nil), let view else { return }
        contextMenuChanged = false
        hadContextMenu = menu != nil
        view.setContextMenu(WinUIMenu(menu))
    }

    func makeView() -> WinUIView? {
        if let registered = WinUIRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? WinUIScrollView { follow(scroll) }
            return registered
        }
        guard !NodeType.viewlessTypes.contains(type) else { return nil }

        switch type {
        case .page, .overlay: return WinUISingleChildView()
        case .navigationStack: return WinUINavigationView()
        case .splitView: return WinUISplitView()
        case .tabbedView: return WinUITabbedView()
        default: return WinUIUnsupportedView(type)
        }
    }

    /// Whether the host shows an entry as unsupported: no registration makes it, and it is no page's, no part of
    /// another view and no structure.
    static func showsUnsupported(_ type: NodeType) -> Bool {
        !WinUIRegistrations.registry.realization.elements.contains(type.name)
            && !NodeType.viewlessTypes.contains(type) && !NodeType.pageTypes.contains(type) && type != .overlay
    }

    /// Puts the changed properties on the element - a patch's or a frame's, the program's write either way: its
    /// registration's first, then what every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        let taken = WinUIRegistrations.registry.apply(
            changed, to: view, of: type,
            reading: { [element] in element.value($0) },
            carriedIn: { [element] in element.driven[$0]?.mode == .in })

        let own = changed.subtracting(taken)
        for property in own {
            switch property {
            case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
            case .isVisible: view.setShown(isShown)
            case .background: (view as? WinUILayoutView)?.setBackground(value(.background))
            case .padding where type == .page:
                let sides = value(.padding)?.numbers ?? []
                (view as? WinUISingleChildView)?.padding =
                    sides.count >= 4 ? Insets(sides[0], sides[1], sides[2], sides[3]) : Insets(0)
            default: break
            }
        }
        if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
        if !own.isDisjoint(with: MountedElement.accessibilityProperties) {
            view.setAccessibility(element.accessibilityWords)
        }
        if let layers = view as? WinUIZStackView { layers.placement = element.placement }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Forgets the sizes kept by this element's layout and every one above it, and asks WinUI to measure again.
    func invalidateMeasurements() {
        var element: WinUIElement? = self
        while let each = element {
            (each.view as? WinUILayoutView)?.forgetMeasurements()
            element = each.parent
        }

        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// Hands the scroller's reports to this element, and its wish for the display's frames to the renderer.
    private func follow(_ scroll: WinUIScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.runtime.frames.serve(scroll, order: scroll.number) }
        }
    }

    /// The view of this element or the nearest one above it.
    var nearestView: WinUIView? {
        view ?? parent?.nearestView
    }
}
