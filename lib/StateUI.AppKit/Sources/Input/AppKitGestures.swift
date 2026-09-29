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

/// AppKit's drag recognizer: a press dragged, told as it starts, runs and ends, with how far it has come, from the top
/// left.
@MainActor
final class AppKitPanRecognizer: NSPanGestureRecognizer {
    private let hearing: AppKitHearing
    private let actionTarget: AppKitGestureAction

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

    /// A press dragged, at `phase`, `x` across and `y` down from where it began.
    func dragged(_ phase: GesturePhase, x: Double, y: Double) {
        hearing(.drag(phase, x: x, y: y))
    }

    private func recognized(_ recognizer: NSPanGestureRecognizer) {
        let moved = recognizer.translation(in: recognizer.view)
        // AppKit's translation grows upward in a view drawn from the bottom.
        let down = recognizer.view?.isFlipped == false ? -moved.y : moved.y
        let phase: GesturePhase? = switch recognizer.state {
        case .began: .started
        case .changed: .running
        case .ended: .completed
        case .cancelled, .failed: .canceled
        default: nil
        }
        guard let phase else { return }
        dragged(phase, x: Double(moved.x), y: Double(down))
    }
}

/// AppKit's trackpad pinch, each step told by the scale since the last - the host layer's `PinchStep` - and where it
/// is, as shares of the view's size.
@MainActor
final class AppKitPinchRecognizer: NSMagnificationGestureRecognizer {
    private let hearing: AppKitHearing
    private let actionTarget: AppKitGestureAction
    private var steps = PinchStep()

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
        hearing(.pinch(phase, scale: steps.step(phase, scale: scale), at: at))
    }

    private func recognized(_ recognizer: NSMagnificationGestureRecognizer) {
        let phase: GesturePhase? = switch recognizer.state {
        case .began: .started
        case .changed: .running
        case .ended: .completed
        case .cancelled, .failed: .canceled
        default: nil
        }
        guard let phase else { return }
        let view = recognizer.view
        let at = PinchStep.share(
            of: view.map { $0.topLeft(recognizer.location(in: $0)) },
            width: Double(view?.bounds.width ?? 0), height: Double(view?.bounds.height ?? 0))
        pinched(phase, scale: Double(1 + recognizer.magnification), at: at)
    }
}

/// Pointer tracking that can sit on any native control without replacing it or intercepting its button action: the
/// pointer coming, moving, pressing, letting go and leaving, where it is from the view's top left.
@MainActor
final class AppKitPointerRecognizer: NSGestureRecognizer {
    private var hearing: AppKitHearing?
    private weak var trackedView: NSView?
    private var trackingArea: NSTrackingArea?

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
        hearing?(.pointer(event, point))
    }

    @objc func mouseEntered(with event: NSEvent) {
        pointed(.pointerEntered, at: point(in: event))
    }

    @objc func mouseExited(with event: NSEvent) {
        pointed(.pointerExited, at: point(in: event))
    }

    @objc func mouseMoved(with event: NSEvent) {
        pointed(.pointerMoved, at: point(in: event))
    }

    override func mouseDown(with event: NSEvent) {
        pointed(.pointerPressed, at: point(in: event))
        state = .began
    }

    override func mouseDragged(with event: NSEvent) {
        pointed(.pointerMoved, at: point(in: event))
        state = .changed
    }

    override func mouseUp(with event: NSEvent) {
        pointed(.pointerReleased, at: point(in: event))
        state = .ended
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

    private func point(in event: NSEvent) -> Point {
        guard let view = trackedView else { return Point(x: 0, y: 0) }
        return view.topLeft(view.convert(event.locationInWindow, from: nil))
    }
}

#endif
