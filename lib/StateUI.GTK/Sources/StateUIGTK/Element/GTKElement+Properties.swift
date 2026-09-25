// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The widget: made, and given the element's properties.
extension GTKElement {
    /// Properties a parent reads into its child's layout item: a change arranges the parent again.
    static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .isVisible,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .area,
    ]

    /// Properties drawn without changing any measurement; any other one measures the element again.
    static let unmeasuredProperties = Set<Prop>([
        .opacity, .background, .textColor, .isEnabled,
        .isOn, .value, .minimum, .maximum,
        .stroke, .strokeWidth, .shape, .clipsContent, .ignoresInput,
    ]).union(transformProperties)

    /// Properties that move, turn and scale the view where its layout put it.
    static let transformProperties: Set<Prop> = [
        .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX, .pivotY,
    ]

    /// The entries that have no view of their own: structure, and the parts of another's view.
    static let viewlessTypes: Set<NodeType> = [
        .application, .scene, .window, .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
        .titleView, .toolbarItems, .toolbarItem, .menuBar, .contextMenu, .menu, .menuItem, .menuSeparator, .spans,
        .span,
    ]

    /// The arrangements of pages a window shows.
    static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]

    func makeView() -> GTKView? {
        if let registered = GTKRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? GTKScrollView { follow(scroll) }
            return registered
        }

        guard !Self.viewlessTypes.contains(type) else { return nil }

        switch type {
        case .page: return GTKSingleChildView()
        case .overlay:
            let overlay = GTKSingleChildView()
            overlay.passesBeside = true
            return overlay
        case .navigationStack: return GTKNavigationView()
        case .splitView: return GTKSplitView()
        case .tabbedView: return GTKTabbedView()
        default: return GTKUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the widget as the program's write: its registration's first, then what
    /// every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: Self.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
            let taken = GTKRegistrations.registry.apply(
                changed, to: view, of: type,
                reading: { [element] in element.value($0) },
                carriedIn: { [element] in element.driven[$0]?.mode == .in })

            let own = changed.subtracting(taken)
            for property in own {
                switch property {
                case .opacity: view.setOpacity(value(.opacity)?.number ?? 1)
                case .isVisible: view.setShown(isShown)
                case .background: (view as? GTKLayoutView)?.setBackground(value(.background))
                case .padding where type == .page:
                    let sides = value(.padding)?.numbers ?? []
                    (view as? GTKSingleChildView)?.padding =
                        sides.count >= 4 ? Insets(sides[0], sides[1], sides[2], sides[3]) : Insets(0)
                default: break
                }
            }
            if !own.isDisjoint(with: Self.transformProperties) { view.setTransform(transform) }
            if let layers = view as? GTKZStackView { layers.placement = placement }
        }

        if !changed.subtracting(ownPlacementRun).isSubset(of: Self.unmeasuredProperties) { invalidateMeasurements() }
    }

    /// The layout's own placement run, where a state drives one: it moves the children without changing
    /// what the layout measures.
    var ownPlacementRun: Set<Prop> {
        element.driven[.area]?.kind == .placement ? [.area] : []
    }

    /// The places an engine gives this layout's children, one each; nil while no state drives them.
    var placement: HostPlacementRun? {
        guard !ownPlacementRun.isEmpty, let carried = element.carriedValue(.area) else { return nil }
        return StateUIHost.placements(from: carried)
    }

    /// How the view is moved, turned and scaled; `scale` multiplies both axes on top of `scaleX` and `scaleY`.
    var transform: HostDrawingTransform {
        let scale = value(.scale)?.number ?? 1
        return HostDrawingTransform(
            translationX: value(.translationX)?.number ?? 0,
            translationY: value(.translationY)?.number ?? 0,
            rotation: value(.rotation)?.number ?? 0,
            rotationX: value(.rotationX)?.number ?? 0,
            rotationY: value(.rotationY)?.number ?? 0,
            scaleX: scale * (value(.scaleX)?.number ?? 1),
            scaleY: scale * (value(.scaleY)?.number ?? 1),
            pivotX: value(.pivotX)?.number ?? 0.5,
            pivotY: value(.pivotY)?.number ?? 0.5)
    }

    /// Forgets the sizes kept by this element's layout and every one above it, and asks GTK to measure again.
    func invalidateMeasurements() {
        var element: GTKElement? = self
        while let each = element {
            (each.view as? GTKLayoutView)?.forgetMeasurements()
            element = each.parent
        }

        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// Hears the scroller's movement on the display's frames: where it went, and that it came to rest.
    private func follow(_ scroll: GTKScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.requestFrames(for: scroll) }
        }
    }

    /// The view of this element or the nearest one above it.
    var nearestView: GTKView? {
        view ?? parent?.nearestView
    }
}
