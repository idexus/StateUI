// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The widget: made, and given the element's properties.
extension GTKElement {
    func makeView() -> GTKView? {
        if type == .itemsView, let host {
            return GTKItemsView(cells: ItemsCells(element, in: host.runtime), reducesMotion: { [weak host] in
                host?.runtime.reducesMotion() ?? false
            })
        }
        if element.isDrawnByParent(in: GTKRegistrations.registry) || element.isViewless { return nil }
        if type == .divider { return GTKDividerView(inRow: element.parent?.type == .hStack) }
        if let registered = GTKRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) },
            made: element.made
        ) {
            if let scroll = registered as? GTKScrollView { follow(scroll) }
            return registered
        }

        switch type {
        case .page: return GTKSingleChildView()
        case .overlay:
            let overlay = GTKSingleChildView()
            overlay.passesBeside = true
            return overlay
        case .navigationStack: return GTKNavigationView()
        case .splitView: return GTKSplitView()
        case .tabView: return GTKTabView()
        default: return GTKUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the widget - a patch's or a frame's, the program's write either way: its
    /// registration's first, then what every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        let taken = GTKRegistrations.registry.apply(changed, to: view, presenting: element)

        let own = changed.subtracting(taken)
        for property in own {
            switch property {
            case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
            case .isEnabled: view.setEnabled(element.presented(.isEnabled)?.bool ?? true)
            case .ignoresInput: view.setIgnoresInput(value(.ignoresInput)?.bool ?? false)
            case .isVisible: view.setShown(isShown)
            case .tooltip: view.setTooltip(element.string(.tooltip))
            // GTK blurs nothing behind a widget: a blur's or glass's colour stands in, its tint over it.
            case .background: view.setBackground(HostMaterial(value(.background)).painted)
            default: break
            }
        }
        if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
        if !own.isDisjoint(with: MountedElement.accessibilityProperties) {
            view.setAccessibility(element.accessibilityWords)
        }
        if let layers = view as? GTKZStackView { layers.placement = element.placement }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Forgets the sizes kept by this element's layout and every one above it - up to an ItemsView's entry, whose
    /// cell measures it again (`MountedElement.measuredUpward`) - and asks GTK to measure again.
    /// Design: docs/design/host/layout.md#measured-once
    func invalidateMeasurements() {
        let walk = element.measuredUpward()
        for each in walk.layouts { (each.gtk.view as? GTKLayoutView)?.forgetMeasurements() }
        if let entry = walk.entry { (entry.parent?.gtk.view as? GTKItemsView)?.remeasure(entry) }
        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// Hears the scroller's movement on the display's frames: where it went, and that it came to rest.
    private func follow(_ scroll: GTKScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.runtime.frames.serve(scroll, order: scroll.number) }
        }
    }

    /// The view of this element or the nearest one above it.
    var nearestView: GTKView? {
        view ?? parent?.nearestView
    }
}
