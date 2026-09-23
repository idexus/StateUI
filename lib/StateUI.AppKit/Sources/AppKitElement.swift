// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Why a page became visible or stopped: a navigation carries three phases, an appearance two.
enum AppKitPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// The AppKit half of a mounted element: its native view and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class AppKitElement: NSObject, NativeElement {
    /// The element of the mounted tree this is the AppKit half of; it owns this half.
    unowned let element: MountedElement
    private(set) var view: NSView?

    /// How StateUI draws the view over the frame AppKit gives it.
    var drawing: AppKitViewDrawing?

    weak var host: AppKitRenderer?
    let core = CoreLink()
    var widthConstraint: NSLayoutConstraint?
    var heightConstraint: NSLayoutConstraint?
    var minimumWidthConstraint: NSLayoutConstraint?
    var minimumHeightConstraint: NSLayoutConstraint?
    var maximumWidthConstraint: NSLayoutConstraint?
    var maximumHeightConstraint: NSLayoutConstraint?
    var buttonWidthConstraint: NSLayoutConstraint?
    var buttonHeightConstraint: NSLayoutConstraint?
    var observesFrame = false
    var frameObservedViews: [NSView] = []
    var frameQueued = false
    var lastFrameReport: [Double]?

    /// The focus this element last reported, where it follows its focus.
    var reportedFocus = false

    /// Whether this element is fading out: still visible, deaf to input, and
    /// hidden once the fade lands.
    var leaving = false
    var tapRecognizer: AppKitTapRecognizer?
    var swipeRecognizer: AppKitSwipeRecognizer?
    var panRecognizer: AppKitPanRecognizer?
    var pinchRecognizer: AppKitPinchRecognizer?
    var pointerRecognizer: AppKitPointerRecognizer?
    var accessibilityDefaults: (
        isElement: Bool,
        role: NSAccessibility.Role?
    )?
    var accessibilityThroughCell: Bool?
    var accessibilityChildrenSuppressed = false
    var panFromX: Double = 0
    var panFromY: Double = 0
    var pagePresented = false
    var pendingTabFallback: Int?
    var platformMenuItem: NSMenuItem?

    /// What the element showed before the patch being applied, held by its owners so a child
    /// the patch removes can still be told it stopped showing.
    var previouslyShown: [MountedElement] = []

    init(_ element: MountedElement, host: AppKitRenderer) {
        self.element = element
        self.host = host
        super.init()

        view = makeView()
        drawing = view.map { AppKitViewDrawing($0) }
    }

    // MARK: - The element's tree, read through its mounted element

    var id: ElementId { element.id }
    var type: NodeType { element.type }
    var mount: UInt64 { element.mount }
    var parent: AppKitElement? { element.parent?.appKit }
    var children: [AppKitElement] { element.children.map(\.appKit) }
    var recycledChildren: [AppKitElement] { element.recycledChildren.map(\.appKit) }
    var recycles: Bool { element.recycles }
    var events: [Event: Int32] { element.events }
    var driven: [Prop: HostStateBinding] { element.driven }
    var motion: HostLayoutMotion? { element.motion }
    var framesRead: Bool { element.framesRead }
    func value(_ property: Prop) -> HostValue? { element.value(property) }
    func resolvedValue(_ property: Prop) -> HostValue? { element.resolvedValue(property) }
    func string(_ property: Prop) -> String? { element.string(property) }
    func name(_ property: Prop) -> String? { element.name(property) }
    func number(_ property: Prop) -> Double? { element.number(property) }
    func bool(_ property: Prop) -> Bool? { element.bool(property) }
    func handler(_ event: Event) -> Int32? { element.handler(event) }

    // MARK: - The native half's part in a patch

    var presentsView: Bool { view != nil }

    func willApply() {
        previouslyShown = shownChildren.map(\.element)
    }

    func adopted() {
        leaving = false
        lastFrameReport = nil
        reportedFocus = false
        pagePresented = false
        pendingTabFallback = nil
    }

    func standingValue(_ property: Prop) -> HostValue? {
        if type == .window, let value = host?.standingWindowValue(for: self, property: property) {
            return value
        }

        switch (type, property) {
        case (_, .opacity):
            return .number(Double(view?.alphaValue ?? 1))
        case (.slider, .value):
            return (view as? AppKitSliderView).map { .number($0.doubleValue) }
        case (.progressBar, .progress):
            return (view as? AppKitProgressView).map { .number($0.doubleValue) }
        default:
            return nil
        }
    }

    func animates(_ property: Prop) -> Bool {
        AppKitTransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        configureContextMenu()
        configureGestures()
        configureLayoutMotion()
        arrangeChildren()
        configureFrameObservation()
        reconcilePresentation(from: previouslyShown.map(\.appKit))
        previouslyShown = []
        reportTabFallback()
    }

    func letGo() {
        leaving = false
    }

    func leave() {
        releaseNativeAttachments()
    }

    /// Crosses a change of visibility on an element already shown: out -
    /// fading to nothing, deaf to input, hidden when the fade lands - or in,
    /// from nothing up to the opacity the tree describes. Under the element's
    /// own motion, or the application's where it says nothing; at once under
    /// `.motion(.none)`, an engine's value, or a user who asked for less.
    func crossVisibility() {
        guard let host, let view else { return }
        let visible = value(.isVisible)?.bool != false
        let law = host.layoutMotion.law(of: motion)
        let opacity = resolvedValue(.opacity) ?? .number(1)

        if !visible {
            guard !view.isHidden, !leaving, let law else { return }
            leaving = true
            let started = host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(Double(view.alphaValue)),
                target: .number(0),
                motion: law,
                landed: { [weak self] in self?.crossed() })
            if !started { leaving = false }
        } else if leaving {
            // BACK BEFORE IT WENT: up again from where the fade has reached,
            // or at once where nothing moves.
            leaving = false
            host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(Double(view.alphaValue)),
                target: opacity,
                motion: law)
        } else if view.isHidden, let law {
            view.isHidden = false
            host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(0),
                target: opacity,
                motion: law)
        }
    }

    /// The fade out ended - landed, or cut short - and the element goes,
    /// unless it was shown again on the way.
    ///
    /// THE REST OF THE CHANGE the patch began: the layout that places the
    /// element closes over it the way a patch moves its children, rather than
    /// snapping the rows below into the gap.
    func crossed() {
        guard leaving, let view else { return }
        leaving = false
        (view.superview as? AppKitTravellingLayout)?.patchArrived()
        applyVisibility()
        view.invalidateMeasurements()
    }

    /// Shows, hides and fades the view as the tree says - kept visible and
    /// deaf to input while it fades out.
    func applyVisibility() {
        guard let view else { return }
        view.isHidden = !leaving && value(.isVisible)?.bool == false
        view.alphaValue = value(.opacity)?.number ?? 1
        if let hitTestView = view as? AppKitHitTestView {
            // The whole view and its children, or only its own empty area.
            let ignores = value(.ignoresInput)?.bool ?? false
            hitTestView.applyInputTransparency(
                leaving || ignores || value(.letsInputThrough)?.bool == true,
                cascades: leaving || ignores)
        }
    }

    func setRecycled(_ recycled: Bool) {
        for native in presentableViews { native.isHidden = recycled }
    }

    func releaseNativeAttachments() {
        if observesFrame {
            NotificationCenter.default.removeObserver(
                self, name: NSView.frameDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(
                self, name: NSView.boundsDidChangeNotification, object: nil)
            frameObservedViews.removeAll()
            observesFrame = false
        }

        let recognizers: [NSGestureRecognizer?] = [
            tapRecognizer, swipeRecognizer, panRecognizer, pinchRecognizer,
        ]
        for recognizer in recognizers.compactMap({ $0 }) {
            view?.removeGestureRecognizer(recognizer)
        }
        tapRecognizer = nil
        swipeRecognizer = nil
        panRecognizer = nil
        pinchRecognizer = nil
        pointerRecognizer?.detach()
        pointerRecognizer = nil

        if let scroller = view as? AppKitScrollView { host?.stopFrames(for: scroller) }
    }

    /// Tells every element in this subtree that follows its focus where the
    /// focus now is, where that has changed.
    func reportFocus() {
        if let handler = events[.isFocusedChanged], let view {
            let focused = AppKitFocus.holds(view, view.window?.firstResponder)
            if focused != reportedFocus {
                reportedFocus = focused
                host?.dispatch(handler, payload: [.bool(focused)])
            }
        }
        for child in children { child.reportFocus() }
    }

    /// Hands a layout what its children travel under, and tells it a patch
    /// reached it: its next arrangement places what the patch changed.
    ///
    /// Only a patch says so. A frame the display cycle presents arranges the
    /// same children in a room that is moving, and they follow it.
    func configureLayoutMotion() {
        guard let layout = view as? AppKitTravellingLayout else { return }
        layout.layoutMotion = host?.layoutMotion
        layout.motion = motion
        layout.framesRead = framesRead
        layout.patchArrived()
    }

    /// Whether this element can fade in as it joins a standing layout: its
    /// view presents its opacity, and no state owns that opacity.
    var fadesIn: Bool {
        view != nil && driven[.opacity] == nil
            && AppKitTransitionSurface.presents(.opacity, on: type)
    }

    /// Fades this element in as it joins a layout that was already standing:
    /// the other half of the children around it sliding to make room.
    ///
    /// Not an opacity already travelling: the patch that set it said how it
    /// moves, and a fade over it would be a second answer for one value.
    func fadeIn(under motion: Motion) {
        guard fadesIn, let host, let view,
              host.tree.presentedPropertyValue(mount: mount, property: .opacity) == nil
        else { return }

        host.tree.receiveProperty(
            mount: mount,
            property: .opacity,
            standing: .number(0),
            target: resolvedValue(.opacity) ?? .number(1),
            motion: motion)
        view.alphaValue = value(.opacity)?.number ?? 1
    }

    /// Presents one display frame of this element's own changed properties.
    func presentFrame(_ properties: Set<Prop>) -> FrameImpact {
        applyProperties(changed: properties)

        var impact = FrameImpact(content: true)
        // An element without a native view - a span, a formatted string - is
        // drawn by the nearest ancestor that has one, which arranges again. A
        // layout's own placement run moves its children inside the room it
        // already has, so it arranges the layout and not its parent.
        let arranged = properties.subtracting(ownPlacementRun)
        if view == nil || !arranged.isDisjoint(with: Self.arrangedProperties) {
            impact.arrangement = true
        }
        if needsWindowSynchronization(for: properties) {
            impact.windowChrome = true
        }
        return impact
    }

}

extension MountedElement {
    /// This element's AppKit half.
    var appKit: AppKitElement { native as! AppKitElement }
}
#endif
