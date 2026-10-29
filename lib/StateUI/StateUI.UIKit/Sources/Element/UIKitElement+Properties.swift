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
        let view = makeOwnView()
        (view as? UIKitRefreshing)?.refresh.onPulled = { [weak self] in self?.pulled() ?? false }
        return view
    }

    private func makeOwnView() -> UIView? {
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
        // An arrangement's background is its pages': each that says none stands on it.
        for page in element.pagesGroundedAnew(by: changed) {
            (page.native as? UIKitElement)?.applyProperties(changed: [.background])
        }
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
                    view.backgroundColor = HostMaterial(element.drawnBackground).painted.flatMap(UIColor.init(stateUI:))
                    (controller as? UIKitPageController)?.showBackground()
                case .ignoresSafeArea:
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
        // A bottom bar's size is its page's to place: the page under the arrangement around the bar lays out again.
        if let slot = walk.layouts.firstIndex(where: { $0.type == .bottomBar }),
           let around = walk.layouts[slot...].first(where: { NodeType.pageTypes.contains($0.type) }) {
            around.visiblePage?.uiKit.controller?.view.setNeedsLayout()
        }
        view?.window?.rootViewController?.view.setNeedsLayout()
    }
}

extension UIKitElement {
    /// What VoiceOver meets of the view, by the host layer's rule - its words and taps as they stand now.
    func applyAccessibility() {
        guard let view else { return }
        let target = (view as? UIKitAccessibilityPresenting)?.presentedControl ?? view
        if accessibilityStanding == nil { accessibilityStanding = target.isAccessibilityElement }
        let words = element.accessibilityWords
        target.accessibility(words, holdingNoChildren: element.children.isEmpty, standing: accessibilityStanding ?? false)
        (view as? UIKitSwitchView)?.authoredLabel = words.label
        // A kind said stands in place of the view's own kind, and a value said over its own: unsaid again, the view's
        // own come back.
        if accessibilityOwnKind == nil { accessibilityOwnKind = target.accessibilityTraits.intersection(Self.kinds) }
        if let role = words.role {
            target.accessibilityTraits = target.accessibilityTraits.subtracting(Self.kinds)
                .union(Self.accessibilityTrait(role))
        } else if accessibilityKindSaid {
            target.accessibilityTraits = target.accessibilityTraits.subtracting(Self.kinds)
                .union(accessibilityOwnKind ?? [])
        }
        accessibilityKindSaid = words.role != nil
        if words.value != nil || accessibilityValueSaid { target.accessibilityValue = words.value }
        accessibilityValueSaid = words.value != nil
        applyReaderActions(words, to: target)
    }

    /// The actions VoiceOver offers on the view, and its steps of a view StateUI draws that says it is adjustable -
    /// each heard by the host layer's rule.
    /// Design: docs/design/platforms/uikit/controls.md#accessibility
    private func applyReaderActions(_ words: AccessibilityWords, to target: UIView) {
        let heard: (HeardInput) -> Bool = { [weak self] heard in
            guard let self, let host else { return false }
            return element.hear(heard, in: host.runtime)
        }
        if !words.actions.isEmpty || accessibilityActionsSaid {
            target.accessibilityCustomActions = words.actions.isEmpty ? nil : words.actions.map { name in
                UIAccessibilityCustomAction(name: name) { _ in heard(.accessibilityAction(name)) }
            }
        }
        accessibilityActionsSaid = !words.actions.isEmpty
        (target as? UIKitSteppable)?.stepAction = words.role == .adjustable
            ? { step in _ = heard(.accessibilityAdjustment(step)) }
            : nil
    }

    /// The traits saying what kind of thing a view is.
    static let kinds: UIAccessibilityTraits = [.button, .toggleButton, .adjustable, .link, .image, .staticText]

    /// UIKit's trait for a kind the element says it is.
    static func accessibilityTrait(_ role: AccessibilityRole) -> UIAccessibilityTraits {
        switch role {
        case .button: .button
        case .toggle: .toggleButton
        case .adjustable: .adjustable
        case .link: .link
        case .image: .image
        case .text: .staticText
        }
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
    /// A StateUI color: four sRGB channels, drawn in sRGB exactly; nil for a value that is no color.
    convenience init?(stateUI value: HostValue) {
        guard let color = value.fractions else { return nil }
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
#endif
