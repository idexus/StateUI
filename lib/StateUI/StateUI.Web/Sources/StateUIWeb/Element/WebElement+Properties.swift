// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The DOM element: made, and given the element's properties.
extension WebElement {
    func makeView() -> WebDOMView? {
        if let registered = WebRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? WebScrollView { follow(scroll) }
            return registered
        }

        guard !NodeType.viewlessTypes.contains(type) else { return nil }

        switch type {
        case .page: return WebLayoutView(tag: "section", arrangement: .single)
        case .navigationStack: return WebNavigationView()
        case .splitView: return WebSplitView()
        default: return WebUnsupportedView(type)
        }
    }

    /// Puts the changed properties on the DOM element, its registration's first, then what every element takes.
    /// Design: docs/design/host/patches.md#program-write
    func applyProperties(changed: Set<Prop>) {
        guard let view else { return }

        let taken = WebRegistrations.registry.apply(
            changed, to: view, of: type,
            reading: { [element] in element.value($0) },
            carriedIn: { [element] in element.driven[$0]?.mode == .in })

        let own = changed.subtracting(taken)
        for property in own {
            switch property {
            case .opacity: view.setOpacity(element.value(.opacity)?.number ?? 1)
            case .isEnabled: view.setEnabled(element.value(.isEnabled)?.bool ?? true)
            case .isVisible: view.setShown(element.standsShown)
            case .background: (view as? WebLayoutView)?.setBackground(element.value(.background))
            case .ignoresInput: view.style("pointer-events", element.value(.ignoresInput)?.bool == true ? "none" : nil)
            default: break
            }
        }
        if !own.isDisjoint(with: MountedElement.transformProperties) { view.setTransform(element.drawingTransform) }
        if !own.isDisjoint(with: MountedElement.accessibilityProperties) { view.setAccessibility(element.accessibilityWords) }
        if let layers = view as? WebLayoutView, layers.arrangement == .layers { layers.setPlacement(element.placement) }
    }

    /// Hears the scroller's movement on the display's frames: where it went, and that it came to rest.
    private func follow(_ scroll: WebScrollView) {
        scroll.onOffsetChanged = { [weak self] old, new in
            guard let self, let host else { return }
            element.reportScrolled(from: old, to: new, in: host.runtime)
            host.runtime.frames.laidOut()
        }
        scroll.onScrollStopped = { [weak self] in self?.send(.scrollStopped, []) }
        scroll.movement.onFramesWanted = { [weak self, weak scroll] in
            if let scroll { self?.host?.runtime.frames.serve(scroll, order: scroll.serial) }
        }
    }
}
