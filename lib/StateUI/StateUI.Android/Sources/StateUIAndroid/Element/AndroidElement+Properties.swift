// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native view: made, and given the element's properties.
extension AndroidElement {
    func makeView() -> AndroidView? {
        if type == .itemsView, let host {
            return AndroidItemsView(cells: ItemsCells(element, in: host.runtime), reducesMotion: { [weak host] in
                host?.runtime.reducesMotion() ?? false
            })
        }
        if element.isDrawnByParent(in: AndroidRegistrations.registry) || element.isViewless { return nil }
        if let registered = AndroidRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) },
            made: element.made
        ) {
            if let scroll = registered as? AndroidScrollView { follow(scroll) }
            return registered
        }

        switch type {
        case .page, .overlay:
            return AndroidSingleChildView()

        case .navigationStack:
            return AndroidNavigationView(reducesMotion: { [weak host] in host?.runtime.reducesMotion() ?? false })

        case .splitView:
            return AndroidSplitView()

        case .tabView:
            return AndroidTabView()

        default:
            return AndroidUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the view as the program's write: its registration's first,
    /// then what every view takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
            let taken = AndroidRegistrations.registry.apply(changed, to: view, presenting: element)

            let own = changed.subtracting(taken)
            for property in own {
                switch property {
                case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
                case .isVisible: view.setShown(isShown)
                // Android blurs nothing behind a view: a blur's or glass's colour stands in, its tint over it.
                case .background: view.setBackground(HostMaterial(value(.background)).painted)
                case .isEnabled: view.setEnabled(element.presented(.isEnabled)?.bool ?? true)
                case .tooltip: view.setTooltip(element.string(.tooltip))
                default: break
                }
            }
            if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
            if !own.isDisjoint(with: MountedElement.accessibilityProperties) {
                view.setAccessibility(element.accessibilityWords) { [weak self] heard in
                    guard let self, let host else { return false }
                    return element.hear(heard, in: host.runtime)
                }
            }
            if let layers = view as? AndroidZStackView { layers.placement = element.placement }
        }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Hands the scroller's reports to this element, and its wish for the display's frames to the renderer.
    private func follow(_ scroll: AndroidScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.runtime.frames.serve(scroll, order: scroll.number) }
        }
    }

    /// Forgets the sizes kept by this element's layout and every one above it - up to an ItemsView's entry, whose
    /// cell measures it again (`MountedElement.measuredUpward`) - and asks Android to measure again.
    /// Design: docs/design/host/layout.md#measured-once
    func invalidateMeasurements() {
        let walk = element.measuredUpward()
        for each in walk.layouts { (each.android.view as? AndroidLayoutView)?.forgetMeasurements() }
        if let entry = walk.entry { (entry.parent?.android.view as? AndroidItemsView)?.remeasure(entry) }
        (view ?? parent?.nearestView)?.requestLayout()
    }

    /// The view of this element or the nearest one above it.
    var nearestView: AndroidView? {
        view ?? parent?.nearestView
    }
}
