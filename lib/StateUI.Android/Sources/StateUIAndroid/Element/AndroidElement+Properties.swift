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
        if let registered = AndroidRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? AndroidScrollView { follow(scroll) }
            return registered
        }

        guard !NodeType.viewlessTypes.contains(type) else { return nil }

        switch type {
        case .page, .overlay:
            return AndroidSingleChildView()

        case .navigationStack:
            return AndroidNavigationView()

        case .splitView:
            return AndroidSplitView()

        case .tabbedView:
            return AndroidTabbedView()

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
            let taken = AndroidRegistrations.registry.apply(
                changed, to: view, of: type,
                reading: { [element] in element.value($0) },
                carriedIn: { [element] in element.driven[$0]?.mode == .in })

            let own = changed.subtracting(taken)
            for property in own {
                switch property {
                case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
                case .isVisible: view.setShown(isShown)
                case .background: view.setBackground(value(.background))
                case .padding where type == .page:
                    let sides = value(.padding)?.numbers ?? []
                    (view as? AndroidSingleChildView)?.padding =
                        sides.count >= 4 ? Insets(sides[0], sides[1], sides[2], sides[3]) : Insets(0)
                default: break
                }
            }
            if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
            if !own.isDisjoint(with: MountedElement.accessibilityProperties) { view.setAccessibility(element.accessibilityWords) }
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

    /// Forgets the sizes kept by this element's layout and every one above it, and asks Android to measure again.
    func invalidateMeasurements() {
        var element: AndroidElement? = self
        while let each = element {
            // An entry of an ItemsView is measured by its cell; the list's own size never follows its items.
            if let items = each.parent?.view as? AndroidItemsView {
                items.remeasure(each.element)
                break
            }
            (each.view as? AndroidLayoutView)?.forgetMeasurements()
            element = each.parent
        }

        (view ?? parent?.nearestView)?.requestLayout()
    }

    /// The view of this element or the nearest one above it.
    var nearestView: AndroidView? {
        view ?? parent?.nearestView
    }
}
