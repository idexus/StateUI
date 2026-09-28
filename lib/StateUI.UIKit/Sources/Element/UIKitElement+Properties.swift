// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The view: made, and given the element's properties - a registered element's by its registration, what every view
/// takes here, by the host layer's reading of it.
extension UIKitElement {
    func makeView() -> UIView? {
        if type == .itemsView, let host {
            return UIKitItemsView(cells: ItemsCells(element, in: host.runtime), reducesMotion: { [weak host] in
                host?.runtime.reducesMotion() ?? false
            })
        }
        if let registered = UIKitRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            if let scroll = registered as? UIKitScrollView { follow(scroll) }
            return registered
        }
        guard !NodeType.viewlessTypes.contains(type) else { return nil }
        guard !Self.showsUnsupported(type) else { return UIKitUnsupportedView(type) }
        let single = UIKitSingleChildView()
        // An overlay lets a touch beside what it holds through to the page under it.
        single.passesBeside = type == .overlay
        return single
    }

    /// Whether the host shows an entry as unsupported: no registration makes it, and it is no page or arrangement of
    /// pages, no overlay and nothing presented without a view.
    static func showsUnsupported(_ type: NodeType) -> Bool {
        !UIKitRegistrations.registry.realization.elements.contains(type.name) && !NodeType.viewlessTypes.contains(type)
            && !NodeType.pageTypes.contains(type) && type != .overlay
    }

    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
            let taken = UIKitRegistrations.registry.apply(
                changed, to: view, of: type,
                reading: { [element] in element.value($0) },
                carriedIn: { [element] in element.driven[$0]?.mode == .in })

            let own = changed.subtracting(taken)
            for property in own {
                switch property {
                case .opacity: drawing?.ownOpacity = element.number(.opacity) ?? 1
                case .isVisible: view.isHidden = !element.standsShown
                case .background: view.backgroundColor = value(.background).flatMap(UIColor.init(stateUI:))
                case .padding where type == .page:
                    (view as? UIKitSingleChildView)?.padding = element.insets(.padding)
                default: break
                }
            }
            if !own.isDisjoint(with: MountedElement.transformProperties) { drawing?.own = element.drawingTransform }
            if !own.isDisjoint(with: MountedElement.accessibilityProperties) { view.accessibility(element.accessibilityWords) }
            if let layers = view as? UIKitZStackView { layers.placement = element.placement }
        }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Forgets what this element's layout and every one around it measured, and lays them out again.
    func invalidateMeasurements() {
        var each: UIKitElement? = self
        while let element = each {
            // An entry of an ItemsView is measured by its cell; the list's own size never follows its items.
            if let items = element.parent?.view as? UIKitItemsView {
                element.view.map { _ in items.remeasure(element.element) }
                return
            }
            (element.view as? UIKitLayoutView)?.forgetMeasurements()
            element.view?.setNeedsLayout()
            each = element.parent
        }
        view?.window?.rootViewController?.view.setNeedsLayout()
    }
}

extension UIView {
    /// The element's words for assistive technology, as VoiceOver reads a view's: what the tree no longer says
    /// falls back to the view's own.
    func accessibility(_ words: AccessibilityWords) {
        accessibilityIdentifier = words.identifier
        accessibilityLabel = words.label
        accessibilityHint = words.hint
        if words.headingLevel > 0 { accessibilityTraits.insert(.header) } else { accessibilityTraits.remove(.header) }
        accessibilityElementsHidden = words.presence == .hiddenWithChildren
        switch words.presence {
        case .met?: isAccessibilityElement = true
        case .hidden?, .hiddenWithChildren?: isAccessibilityElement = false
        case nil: break
        }
    }
}

extension UIColor {
    /// A StateUI colour: four sRGB channels, drawn in sRGB exactly; nil for a value that is no colour.
    convenience init?(stateUI value: HostValue) {
        guard let color = value.color else { return nil }
        self.init(
            red: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha) / 255)
    }
}
#endif
