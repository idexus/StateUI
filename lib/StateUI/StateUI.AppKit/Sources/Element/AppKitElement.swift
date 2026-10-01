// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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

    /// Whether a layout of StateUI's has placed the view.
    var isPlaced = false

    /// Where a label's place travels: its words stand at that size meanwhile.
    /// Design: docs/design/host/motion.md#words-at-their-destination
    var wordsRoom: Rect?

    /// The focus this element last reported, where it follows its focus.
    var reportedFocus = false

    var tapRecognizer: AppKitTapRecognizer?
    var panRecognizer: AppKitPanRecognizer?
    var pinchRecognizer: AppKitPinchRecognizer?
    var pointerRecognizer: AppKitPointerRecognizer?
    var accessibilityDefaults: (
        isElement: Bool,
        role: NSAccessibility.Role?
    )?
    var accessibilityThroughCell: Bool?
    var accessibilityChildrenSuppressed = false
    var platformMenuItem: NSMenuItem?

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
        TransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        if let view, let host { element.applyDrawnChildren(to: view, through: AppKitRegistrations.registry, in: host.runtime) }
        configureContextMenu()
        configureGestures()
        configureLayoutMotion()
        arrangeChildren()
        configureFrameObservation()
    }

    func leave() {
        releaseNativeAttachments()
    }

    /// Crosses a change of visibility by the host layer's rule - out, fading and then hidden, deaf to input
    /// meanwhile; back from where it stands; in from nothing - and as a fade out ends, the layout that places the
    /// element closes over it the way a patch moves its children.
    func crossVisibility() {
        guard view != nil else { return }
        element.crossVisibility(self) { [weak self] in
            guard let view = self?.view else { return }
            (view.superview as? AppKitTravellingLayout)?.places.patchArrived()
            view.invalidateMeasurements()
        }
    }

    /// Shows, hides and fades the view as the tree says - kept visible and
    /// deaf to input while it fades out.
    func applyVisibility() {
        guard let view else { return }
        view.isHidden = !element.standsShown
        view.alphaValue = value(.opacity)?.number ?? 1
        let ignores = value(.ignoresInput)?.bool ?? false
        if let hitTestView = view as? AppKitHitTestView {
            // The whole view and its children, or only its own empty area.
            hitTestView.applyInputTransparency(
                element.isLeaving || ignores || value(.letsInputThrough)?.bool == true,
                cascades: element.isLeaving || ignores)
        } else {
            AppKitIgnoredInput.set(view, ignores: element.isLeaving || ignores)
        }
    }

    func releaseNativeAttachments() {
        host?.runtime.frames.follow(self, order: Int64(truncatingIfNeeded: mount), reads: false)
        if observesFrame {
            NotificationCenter.default.removeObserver(
                self, name: NSView.frameDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(
                self, name: NSView.boundsDidChangeNotification, object: nil)
            frameObservedViews.removeAll()
            observesFrame = false
        }

        let recognizers: [NSGestureRecognizer?] = [
            tapRecognizer, panRecognizer, pinchRecognizer,
        ]
        for recognizer in recognizers.compactMap({ $0 }) {
            view?.removeGestureRecognizer(recognizer)
        }
        tapRecognizer = nil
        panRecognizer = nil
        pinchRecognizer = nil
        pointerRecognizer?.detach()
        pointerRecognizer = nil


    }

    /// Tells every element in this subtree that follows its focus where the
    /// focus now is, where that has changed.
    func reportFocus() {
        if events[.isFocusedChanged] != nil, let view {
            let focused = AppKitFocus.holds(view, view.window?.firstResponder)
            if focused != reportedFocus {
                reportedFocus = focused
                send(.isFocusedChanged, [.bool(focused)])
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
        layout.places.layoutMotion = host?.runtime.layoutMotion
        layout.places.motion = motion
        layout.places.framesRead = framesRead
        layout.places.patchArrived()
    }

    /// Whether this element fades in as it joins a standing layout, by the host layer's rule.
    var fadesIn: Bool {
        view != nil && element.fadesIn(presentsOpacity: TransitionSurface.presents(.opacity, on: type))
    }

    /// Fades this element in as it joins a layout already standing, by the host layer's rule.
    func fadeIn(under motion: Motion) {
        guard fadesIn else { return }
        element.fadeIn(self, under: motion)
    }

    /// Presents one display frame of this element's own changed properties.
    func presentFrame(_ properties: Set<Prop>) {
        applyProperties(changed: properties)
    }

}

extension MountedElement {
    /// This element's AppKit half.
    var appKit: AppKitElement { native as! AppKitElement }
}

/// A view fades by its showing and its opacity, as the host layer's visibility rule moves them.
extension AppKitElement: FadingView {
    var isShown: Bool { view?.isHidden == false }
    var opacity: Double { Double(view?.alphaValue ?? 1) }

    func setShown(_ shown: Bool) {
        applyVisibility()
    }

    func setOpacity(_ opacity: Double) {
        view?.alphaValue = opacity
    }
}
#endif
