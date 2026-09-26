// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native view: made, and given the element's properties.
extension AndroidElement {
    /// Properties a parent reads into its child's layout item: a frame that moves one arranges the parent again.
    static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .isVisible,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .area,
    ]

    /// Properties drawn without changing any measurement; any other one measures the view again.
    static let unmeasuredProperties = Set<Prop>([
        .opacity, .background, .textColor, .placeholderColor, .tint, .isEnabled,
        .isOn, .value, .minimum, .maximum, .cursorPosition, .selectionLength,
        .color, .cornerRadius, .stroke, .strokeWidth, .shape,
    ]).union(transformProperties).union(accessibilityProperties)

    /// Properties that move, turn and scale the view where its layout put it.
    static let transformProperties: Set<Prop> = [
        .translationX, .translationY, .rotation, .rotationX, .rotationY,
        .scale, .scaleX, .scaleY, .pivotX, .pivotY,
    ]

    func makeView() -> AndroidView? {
        if let registered = AndroidRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? AndroidScrollView { follow(scroll) }
            return registered
        }

        switch type {
        case .application, .scene, .window:
            return nil

        case .page, .overlay:
            return AndroidSingleChildView()

        case .navigationStack:
            return AndroidNavigationView()

        case .splitView:
            return AndroidSplitView()

        case .tabbedView:
            return AndroidTabbedView()

        case .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
             .titleView, .toolbarItems, .toolbarItem, .menuBar, .contextMenu,
             .menu, .menuItem, .menuSeparator, .spans, .span:
            return nil

        default:
            return AndroidUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the view as the program's write: its registration's first,
    /// then what every view takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: Self.arrangedProperties) { parent?.invalidateMeasurements() }
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
            if !own.isDisjoint(with: Self.transformProperties) { view.setTransform(transform) }
            if !own.isDisjoint(with: Self.accessibilityProperties) { applyAccessibility(to: view) }
            if let layers = view as? AndroidZStackView { layers.placement = placement }
        }

        if !changed.subtracting(ownPlacementRun).isSubset(of: Self.unmeasuredProperties) { invalidateMeasurements() }
    }

    /// What assistive technology meets.
    static let accessibilityProperties: Set<Prop> = [
        .accessibilityIdentifier, .accessibilityLabel, .accessibilityHint, .accessibilityHeadingLevel,
        .isAccessibilityHidden, .automationExcludedWithChildren,
    ]

    /// Puts the accessibility words on the view together: left out with its children, or hidden, or met,
    /// as the element says - or as the view is of itself where it says nothing.
    private func applyAccessibility(to view: AndroidView) {
        let met: AndroidView.AccessibilityPresence? = switch (
            value(.automationExcludedWithChildren)?.bool, value(.isAccessibilityHidden)?.bool
        ) {
        case (true?, _): .hiddenWithChildren
        case (_, true?): .hidden
        case (_, false?): .met
        default: nil
        }
        view.setAccessibility(
            identifier: value(.accessibilityIdentifier)?.string, label: value(.accessibilityLabel)?.string,
            hint: value(.accessibilityHint)?.string, heading: (value(.accessibilityHeadingLevel)?.enumeration ?? 0) > 0,
            met: met)
    }

    /// The layout's own placement run, where a state drives one: it moves the children without changing
    /// what the layout measures.
    var ownPlacementRun: Set<Prop> {
        element.driven[.area]?.kind == .placement ? [.area] : []
    }

    /// The places an engine gives this layout's children, one each; nil while no state drives them.
    var placement: HostPlacementRun? {
        guard !ownPlacementRun.isEmpty, let carried = element.carriedValue(.area) else { return nil }
        return HostBoundary.placements(from: carried)
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

    /// Hands the scroller's reports to this element, and its wish for the display's frames to the renderer.
    private func follow(_ scroll: AndroidScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in self?.scrolled(from: old, to: new) }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.requestFrames(for: scroll) }
        }
    }

    /// Forgets the sizes kept by this element's layout and every one above it, and asks Android to measure again.
    func invalidateMeasurements() {
        var element: AndroidElement? = self
        while let each = element {
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
