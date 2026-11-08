// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a recognizer heard, handed to its element, which the host layer turns into its events.
typealias AppKitHearing = (HeardInput) -> Void

@MainActor
private final class AppKitGestureAction: NSObject {
    var action: (NSGestureRecognizer) -> Void

    init(_ action: @escaping (NSGestureRecognizer) -> Void) {
        self.action = action
    }

    @objc func invoke(_ recognizer: NSGestureRecognizer) {
        action(recognizer)
    }
}

extension NSView {
    /// `point`, in this view's own coordinates, from its top left: where the host layer measures what it heard.
    func topLeft(_ point: NSPoint) -> Point {
        Point(x: Double(point.x), y: Double(isFlipped ? point.y : bounds.height - point.y))
    }
}

extension GesturePhase {
    /// The phase a gesture of AppKit's at `state` tells; nil for one not under way.
    init?(_ state: NSGestureRecognizer.State) {
        switch state {
        case .began: self = .began
        case .changed: self = .changed
        case .ended: self = .ended
        case .cancelled, .failed: self = .cancelled
        default: return nil
        }
    }
}

/// AppKit's drag recognizer: a press dragged, told as it starts, runs and ends, with how far it has come, from the top
/// left.
@MainActor
final class AppKitPanRecognizer: NSPanGestureRecognizer {
    private let hearing: AppKitHearing
    private let actionTarget: AppKitGestureAction

    /// The drag as the host was told it.
    private var gesture = ToldGesture()

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        actionTarget = AppKitGestureAction { _ in }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        actionTarget.action = { [weak self] recognizer in
            guard let self, let recognizer = recognizer as? NSPanGestureRecognizer else { return }
            recognized(recognizer)
        }
        delaysPrimaryMouseButtonEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPanRecognizer is created in code")
    }

    /// A press dragged, at `phase`, `x` across and `y` down from where it began, `from`, in the view's points.
    func dragged(_ phase: GesturePhase, x: Double, y: Double, from: Point) {
        gesture.told(phase)
        hearing(.drag(phase, x: x, y: y, from: from))
    }

    private func recognized(_ recognizer: NSPanGestureRecognizer) {
        recognized(recognizer.state, at: recognizer.location(in: nil), moved: recognizer.translation(in: nil))
    }

    /// AppKit's drag at `state`, the press at `now` of the window, having moved by `moved` there since it began.
    func recognized(_ state: NSGestureRecognizer.State, at now: NSPoint, moved: NSPoint) {
        guard let phase = GesturePhase(state), let view, gesture.tells(phase) else { return }
        // Where the press is now and where it began, each where the view is drawn, from the view's top left.
        guard let at = view.drawnPoint(fromWindow: now).map(view.topLeft),
              let from = view.drawnPoint(fromWindow: NSPoint(x: now.x - moved.x, y: now.y - moved.y)).map(view.topLeft)
        else {
            // The view is flattened under the drag: the drag under way, if one, is taken away.
            if gesture.takeAway(at: phase) { dragged(.cancelled, x: 0, y: 0, from: .zero) }
            return
        }
        dragged(phase, x: at.x - from.x, y: at.y - from.y, from: from)
    }
}

/// AppKit's trackpad pinch, each step told by the scale since the last - the host layer's `PinchStep` - and where it
/// is, as shares of the view's size.
@MainActor
final class AppKitPinchRecognizer: NSMagnificationGestureRecognizer {
    private let hearing: AppKitHearing
    private let actionTarget: AppKitGestureAction
    private var steps = PinchStep()

    /// The pinch as the host was told it.
    private var gesture = ToldGesture()

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        actionTarget = AppKitGestureAction { _ in }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        actionTarget.action = { [weak self] recognizer in
            guard let self, let recognizer = recognizer as? NSMagnificationGestureRecognizer else { return }
            recognized(recognizer)
        }
        delaysMagnificationEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPinchRecognizer is created in code")
    }

    /// A pinch at `phase`, its magnification since it began `scale`, at `at` in shares of the view's size.
    func pinched(_ phase: GesturePhase, scale: Double, at: Point) {
        gesture.told(phase)
        hearing(.pinch(phase, scale: steps.step(phase, scale: scale), at: at))
    }

    private func recognized(_ recognizer: NSMagnificationGestureRecognizer) {
        recognized(recognizer.state, magnification: Double(recognizer.magnification), at: recognizer.location(in: nil))
    }

    /// AppKit's pinch at `state`, magnified by `magnification` since it began, at `point` of the window.
    func recognized(_ state: NSGestureRecognizer.State, magnification: Double, at point: NSPoint) {
        guard let phase = GesturePhase(state), gesture.tells(phase) else { return }
        let (width, height) = (Double(view?.bounds.width ?? 0), Double(view?.bounds.height ?? 0))
        let drawn = view?.drawnPoint(fromWindow: point)
        if view != nil, drawn == nil {
            // The view is flattened under the pinch: the pinch under way, if one, is taken away.
            if gesture.takeAway(at: phase) { pinched(.cancelled, scale: 1, at: Point(x: 0.5, y: 0.5)) }
            return
        }
        let at = PinchStep.share(of: drawn.map { view?.topLeft($0) ?? .zero }, width: width, height: height)
        pinched(phase, scale: 1 + magnification, at: at)
    }
}

/// AppKit's trackpad rotation, each step told by the degrees clockwise since the last - the host layer's
/// `RotationStep`: AppKit measures it counterclockwise, in radians.
@MainActor
final class AppKitRotationRecognizer: NSRotationGestureRecognizer {
    private let hearing: AppKitHearing
    private let actionTarget: AppKitGestureAction
    private var steps = RotationStep()

    /// The rotation as the host was told it.
    private var gesture = ToldGesture()

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        actionTarget = AppKitGestureAction { _ in }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        actionTarget.action = { [weak self] recognizer in
            guard let self, let recognizer = recognizer as? NSRotationGestureRecognizer else { return }
            recognized(recognizer)
        }
        delaysRotationEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitRotationRecognizer is created in code")
    }

    /// A rotation at `phase`, turned `degrees` clockwise since it began.
    func rotated(_ phase: GesturePhase, degrees: Double) {
        gesture.told(phase)
        hearing(.rotation(phase, degrees: steps.step(phase, degrees: degrees)))
    }

    private func recognized(_ recognizer: NSRotationGestureRecognizer) {
        recognized(recognizer.state, degrees: -Double(recognizer.rotationInDegrees), at: recognizer.location(in: nil))
    }

    /// AppKit's rotation at `state`, turned `degrees` clockwise since it began, at `point` of the window.
    func recognized(_ state: NSGestureRecognizer.State, degrees: Double, at point: NSPoint) {
        guard let phase = GesturePhase(state), gesture.tells(phase) else { return }
        if let view, view.drawnPoint(fromWindow: point) == nil {
            // The view is flattened under the rotation: the rotation under way, if one, is taken away.
            if gesture.takeAway(at: phase) { rotated(.cancelled, degrees: 0) }
            return
        }
        rotated(phase, degrees: degrees)
    }
}

/// A press dragged with ⌥ over a view two fingers move: the press and the view's middle, from the top left, said
/// as the host layer reads them - two fingers, the press and its mirror. A press without ⌥ it leaves at once, and
/// a pan waits for it to.
/// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
final class AppKitMirroredRecognizer: NSGestureRecognizer {
    private let hearing: AppKitHearing

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        super.init(target: nil, action: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitMirroredRecognizer is created in code")
    }

    /// Whether a press with `flags` held is two fingers.
    static func takes(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(.option)
    }

    /// The press at `phase`, at `at`, the view's middle at `middle`: the host's entry.
    func mirrored(_ phase: GesturePhase, at: Point, middle: Point) {
        hearing(.mirrored(phase, at: at, middle: middle))
    }

    override func mouseDown(with event: NSEvent) {
        guard Self.takes(event.modifierFlags), let at = point(of: event) else { return state = .failed }
        state = .began
        said(.began, at: at)
    }

    override func mouseDragged(with event: NSEvent) {
        guard state == .began || state == .changed else { return }
        guard let at = point(of: event) else { return takenAway() }
        state = .changed
        said(.changed, at: at)
    }

    override func mouseUp(with event: NSEvent) {
        guard state == .began || state == .changed else { return }
        guard let at = point(of: event) else { return takenAway() }
        said(.ended, at: at)
        state = .ended
    }

    override func shouldBeRequiredToFail(by other: NSGestureRecognizer) -> Bool {
        other is NSPanGestureRecognizer
    }

    /// The view is flattened under the fingers: the press under way is taken away.
    private func takenAway() {
        said(.cancelled, at: .zero)
        state = .cancelled
    }

    /// Where `event` is in the view, where the view is drawn, from its top left; nil where no point lands in the view.
    private func point(of event: NSEvent) -> Point? {
        guard let view else { return nil }
        return view.drawnPoint(fromWindow: event.locationInWindow).map(view.topLeft)
    }

    /// The press at `phase`, at `at` of the view.
    private func said(_ phase: GesturePhase, at: Point) {
        guard let view else { return }
        let (width, height) = (Double(view.bounds.width), Double(view.bounds.height))
        mirrored(phase, at: at, middle: Point(width / 2, height / 2))
    }
}

/// Pointer tracking that can sit on any native control without replacing it or intercepting its button action: the
/// pointer coming, moving, pressing, letting go and leaving, where it is from the view's top left.
@MainActor
final class AppKitPointerRecognizer: NSGestureRecognizer {
    private var hearing: AppKitHearing?
    private weak var trackedView: NSView?
    private var trackingArea: NSTrackingArea?

    /// Whether the pointer was told to be over the view and not yet to have left.
    private var over = false

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delaysPrimaryMouseButtonEvents = false
    }

    convenience init(hearing: @escaping AppKitHearing) {
        self.init(target: nil, action: nil)
        self.hearing = hearing
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPointerRecognizer is created in code")
    }

    func install(on view: NSView) {
        if trackedView === view { return }
        detach()
        trackedView = view
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil)
        trackingArea = area
        view.addTrackingArea(area)
        view.addGestureRecognizer(self)
        view.window?.acceptsMouseMovedEvents = true
    }

    func detach() {
        if let trackingArea { trackedView?.removeTrackingArea(trackingArea) }
        if let view { view.removeGestureRecognizer(self) }
        trackingArea = nil
        trackedView = nil
    }

    /// The pointer did `event` at `point` of the view, from its top left.
    func pointed(_ event: Event, at point: Point) {
        if event == .pointerEntered || event == .pointerExited { over = event == .pointerEntered }
        hearing?(.pointer(event, point))
    }

    @objc func mouseEntered(with event: NSEvent) {
        told(.pointerEntered, event)
    }

    @objc func mouseExited(with event: NSEvent) {
        told(.pointerExited, event)
    }

    @objc func mouseMoved(with event: NSEvent) {
        told(.pointerMoved, event)
    }

    override func mouseDown(with event: NSEvent) {
        told(.pointerPressed, event)
        state = .began
    }

    override func mouseDragged(with event: NSEvent) {
        told(.pointerMoved, event)
        state = .changed
    }

    override func mouseUp(with event: NSEvent) {
        told(.pointerReleased, event)
        state = .ended
    }

    /// The pointer did `did` at `event`'s place in the view; where no point lands in the view, flattened by its
    /// drawing, the pointer is not over it: it is told to have left, once, and nothing else.
    private func told(_ did: Event, _ event: NSEvent) {
        if let at = point(in: event) {
            pointed(did, at: at)
        } else if over {
            pointed(.pointerExited, at: .zero)
        }
    }

    override func mouseCancelled(with event: NSEvent) {
        state = .cancelled
    }

    override func canPrevent(_ preventedGestureRecognizer: NSGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: NSGestureRecognizer) -> Bool {
        false
    }

    /// Where `event` is in the view, where the view is drawn, from its top left; nil where no point lands in the view.
    private func point(in event: NSEvent) -> Point? {
        guard let view = trackedView else { return nil }
        return view.drawnPoint(fromWindow: event.locationInWindow).map(view.topLeft)
    }
}

#endif
