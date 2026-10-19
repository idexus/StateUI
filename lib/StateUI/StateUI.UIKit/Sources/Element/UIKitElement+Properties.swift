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
        if element.isDrawnByParent(in: UIKitRegistrations.registry) || element.isViewless { return nil }
        if let registered = UIKitRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) },
            made: element.made
        ) {
            if let scroll = registered as? UIKitScrollView { follow(scroll) }
            return registered
        }
        guard !UIKitRegistrations.registry.showsUnsupported(type) else { return UIKitUnsupportedView(type) }
        let single = UIKitSingleChildView()
        // An overlay lets a touch beside what it holds through to the page under it.
        single.passesBeside = type == .overlay
        return single
    }

    func applyProperties(changed: Set<Prop>) {
        guard let view else {
            if !changed.isDisjoint(with: MountedElement.arrangedProperties) { parent?.invalidateMeasurements() }
            return
        }

        ProgramWrite.perform {
            let taken = UIKitRegistrations.registry.apply(changed, to: view, presenting: element)

            let own = changed.subtracting(taken)
            for property in own {
                switch property {
                case .opacity: drawing?.ownOpacity = element.number(.opacity) ?? 1
                case .isVisible: view.isHidden = !element.standsShown
                // A view that is no control tells VoiceOver whether it answers; its hand is the host layer's.
                case .isEnabled:
                    let traits = view.accessibilityTraits
                    view.accessibilityTraits = element.presented(.isEnabled)?.bool == false
                        ? traits.union(.notEnabled) : traits.subtracting(.notEnabled)
                // Ignored, the view and all in it are passed over: a touch goes to what is under it.
                case .ignoresInput: view.isUserInteractionEnabled = element.bool(.ignoresInput) != true
                case .background:
                    view.backgroundColor = HostMaterial(value(.background)).painted.flatMap(UIColor.init(stateUI:))
                    (controller as? UIKitPageController)?.showBackground()
                case .avoidsSafeArea:
                    // A page's content standing against the safe area otherwise: its page stands again.
                    (parent?.controller as? UIKitPageController)?.view.setNeedsLayout()
                default: break
                }
            }
            if !own.isDisjoint(with: MountedElement.transformProperties) { drawing?.own = element.drawingTransform }
            if let layers = view as? UIKitZStackView { layers.placement = element.placement }
        }

        if !changed.subtracting(element.ownPlacementRun).isSubset(of: MountedElement.unmeasuredProperties) {
            invalidateMeasurements()
        }
    }

    /// Forgets what this element's layout and every one around it measured, and lays them out again - up to an
    /// ItemsView's entry, whose cell measures it again (`MountedElement.measuredUpward`).
    /// Design: docs/design/host/layout.md#measured-once
    func invalidateMeasurements() {
        let walk = element.measuredUpward()
        for each in walk.layouts {
            (each.uiKit.view as? UIKitLayoutView)?.forgetMeasurements()
            each.uiKit.view?.setNeedsLayout()
        }
        if let entry = walk.entry {
            (entry.parent?.uiKit.view as? UIKitItemsView)?.remeasure(entry)
            return
        }
        view?.window?.rootViewController?.view.setNeedsLayout()
    }
}

extension UIKitElement {
    /// What VoiceOver meets of the view, by the host layer's rule - its words and taps as they stand now.
    func applyAccessibility() {
        guard let view else { return }
        if accessibilityStanding == nil { accessibilityStanding = view.isAccessibilityElement }
        view.accessibility(
            element.accessibilityWords, holdingNoChildren: element.children.isEmpty,
            standing: accessibilityStanding ?? false)
    }
}

extension UIView {
    /// The element's words for assistive technology, as VoiceOver reads a view's: what the tree no longer says
    /// falls back to the view's own - whether it is met, as it `standing`. A view `holdingNoChildren` of the tree's -
    /// a picker, a spinner - is one thing to the user, so hidden it hides the parts UIKit offers VoiceOver inside it.
    /// Design: docs/design/platforms/uikit/controls.md#accessibility
    func accessibility(_ words: AccessibilityWords, holdingNoChildren: Bool, standing: Bool) {
        accessibilityIdentifier = words.identifier
        accessibilityLabel = words.label
        accessibilityHint = words.hint
        if words.headingLevel > 0 { accessibilityTraits.insert(.header) } else { accessibilityTraits.remove(.header) }
        accessibilityElementsHidden = words.presence == .hiddenWithChildren
            || (words.presence == .hidden && holdingNoChildren)
        isAccessibilityElement = words.isElement(standing: standing)
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
