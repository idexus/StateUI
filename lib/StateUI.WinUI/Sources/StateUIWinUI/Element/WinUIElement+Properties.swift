// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The native element: made, and given the element's properties.
extension WinUIElement {
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
        .translationX, .translationY, .rotation, .scale, .scaleX, .scaleY, .pivotX, .pivotY,
    ]

    /// The arrangements of pages a window shows.
    static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]

    /// The entries that have no view of their own: structure, and the parts of another's view.
    static let viewlessTypes: Set<NodeType> = [
        .application, .scene, .window, .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
        .titleView, .toolbarItems, .toolbarItem, .menuBar, .contextMenu, .menu, .menuItem, .menuSeparator, .spans,
        .span,
    ]

    func makeView() -> WinUIView? {
        if let registered = WinUIRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? WinUIScrollView { follow(scroll) }
            return registered
        }
        guard !Self.viewlessTypes.contains(type) else { return nil }

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
        !WinUIRegistrations.registry.realization.elements.contains(type.name) && !viewlessTypes.contains(type)
            && !pageTypes.contains(type) && type != .overlay
    }

    /// Puts the changed properties on the element as the program's write: its registration's first,
    /// then what every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: Self.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
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
            if !own.isDisjoint(with: Self.transformProperties) { view.setTransform(transform) }
            if let layers = view as? WinUIZStackView { layers.placement = placement }
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

    /// Forgets the sizes kept by this element's layout and every one above it, and asks WinUI to measure again.
    func invalidateMeasurements() {
        var element: WinUIElement? = self
        while let each = element {
            (each.view as? WinUILayoutView)?.forgetMeasurements()
            element = each.parent
        }

        (view ?? parent?.nearestView)?.invalidateMeasure()
    }

    /// How the view is moved, turned and scaled; `scale` multiplies both axes on top of `scaleX` and `scaleY`.
    var transform: HostDrawingTransform {
        let scale = value(.scale)?.number ?? 1
        return HostDrawingTransform(
            translationX: value(.translationX)?.number ?? 0,
            translationY: value(.translationY)?.number ?? 0,
            rotation: value(.rotation)?.number ?? 0,
            rotationX: 0,
            rotationY: 0,
            scaleX: scale * (value(.scaleX)?.number ?? 1),
            scaleY: scale * (value(.scaleY)?.number ?? 1),
            pivotX: value(.pivotX)?.number ?? 0.5,
            pivotY: value(.pivotY)?.number ?? 0.5)
    }

    /// Hands the scroller's reports to this element, and its wish for the display's frames to the renderer.
    private func follow(_ scroll: WinUIScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.requestFrames(for: scroll) }
        }
    }

    /// The view of this element or the nearest one above it.
    var nearestView: WinUIView? {
        view ?? parent?.nearestView
    }
}
