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
            return registered
        }

        guard !NodeType.viewlessTypes.contains(type) else { return nil }

        switch type {
        case .page: return WebLayoutView(tag: "section", arrangement: .single)
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

        for property in changed.subtracting(taken) {
            switch property {
            case .opacity: view.setOpacity(element.value(.opacity)?.number ?? 1)
            case .isEnabled: view.setEnabled(element.value(.isEnabled)?.bool ?? true)
            case .isVisible: view.setShown(element.standsShown)
            case .background: (view as? WebLayoutView)?.setBackground(element.value(.background))
            default: break
            }
        }
    }
}
