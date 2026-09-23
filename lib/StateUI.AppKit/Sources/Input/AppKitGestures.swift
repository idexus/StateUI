// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

enum AppKitGesturePhase: Int32 {
    case started = 0
    case running = 1
    case completed = 2
    case canceled = 3
}

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

/// AppKit's native mouse-drag recognizer expressed in StateUI's stable phase
/// vocabulary and top-left view coordinates.
@MainActor
final class AppKitPanRecognizer: NSPanGestureRecognizer {
    typealias Update = (AppKitGesturePhase, NSPoint) -> Void

    private let update: Update
    private let actionTarget: AppKitGestureAction

    init(update: @escaping Update) {
        self.update = update
        actionTarget = AppKitGestureAction { recognizer in
            guard let recognizer = recognizer as? NSPanGestureRecognizer else { return }
            let translation = recognizer.translation(in: recognizer.view)
            switch recognizer.state {
            case .began: update(.started, .zero)
            case .changed: update(.running, translation)
            case .ended: update(.completed, .zero)
            case .cancelled, .failed: update(.canceled, .zero)
            default: break
            }
        }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        delaysPrimaryMouseButtonEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPanRecognizer is created in code")
    }

    func emitForTesting(_ phase: AppKitGesturePhase, total: NSPoint) {
        update(phase, total)
    }
}

/// A discrete StateUI swipe recognized from AppKit's native mouse pan. The
/// dominant axis answers exactly one direction, so a diagonal gesture never
/// reports a direction set.
@MainActor
final class AppKitSwipeRecognizer: NSPanGestureRecognizer {
    var directions: Int32 = 15
    var threshold: CGFloat = 40

    private let report: (Int32) -> Void
    private let actionTarget: AppKitGestureAction

    init(report: @escaping (Int32) -> Void) {
        self.report = report
        actionTarget = AppKitGestureAction { recognizer in
            guard let recognizer = recognizer as? AppKitSwipeRecognizer,
                  recognizer.state == .ended
            else { return }
            recognizer.reportIfRecognized(recognizer.translation(in: recognizer.view))
        }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        delaysPrimaryMouseButtonEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSwipeRecognizer is created in code")
    }

    override func canPrevent(_ preventedGestureRecognizer: NSGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: NSGestureRecognizer) -> Bool {
        false
    }

    func emitForTesting(total: NSPoint) {
        reportIfRecognized(total)
    }

    private func reportIfRecognized(_ total: NSPoint) {
        let horizontal = abs(total.x) >= abs(total.y)
        let distance = horizontal ? abs(total.x) : abs(total.y)
        guard distance >= max(0, threshold), distance > 0 else { return }

        let direction: Int32
        if horizontal {
            direction = total.x > 0 ? 1 : 2
        } else {
            direction = total.y < 0 ? 4 : 8
        }
        guard directions & direction != 0 else { return }
        report(direction)
    }
}

/// A native trackpad pinch whose cumulative AppKit magnification is converted
/// to StateUI's factor since the preceding report.
@MainActor
final class AppKitPinchRecognizer: NSMagnificationGestureRecognizer {
    typealias Update = (AppKitGesturePhase, CGFloat, NSPoint) -> Void

    private let update: Update
    private let actionTarget: AppKitGestureAction
    private var previousFactor: CGFloat = 1

    init(update: @escaping Update) {
        self.update = update
        actionTarget = AppKitGestureAction { _ in }
        super.init(target: actionTarget, action: #selector(AppKitGestureAction.invoke(_:)))
        actionTarget.action = { [weak self] recognizer in
            guard let self,
                  let recognizer = recognizer as? NSMagnificationGestureRecognizer
            else { return }
            self.recognized(recognizer)
        }
        delaysMagnificationEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPinchRecognizer is created in code")
    }

    override func reset() {
        super.reset()
        previousFactor = 1
    }

    func emitForTesting(
        _ phase: AppKitGesturePhase,
        scale: CGFloat,
        origin: NSPoint
    ) {
        update(phase, scale, origin)
    }

    private func recognized(_ recognizer: NSMagnificationGestureRecognizer) {
        let factor = max(0.000_001, 1 + recognizer.magnification)
        let origin: NSPoint
        if let view = recognizer.view, view.bounds.width > 0, view.bounds.height > 0 {
            let point = recognizer.location(in: view)
            origin = NSPoint(
                x: (point.x - view.bounds.minX) / view.bounds.width,
                y: (point.y - view.bounds.minY) / view.bounds.height)
        } else {
            origin = NSPoint(x: 0.5, y: 0.5)
        }

        switch recognizer.state {
        case .began:
            previousFactor = factor
            update(.started, 1, origin)
        case .changed:
            update(.running, factor / max(0.000_001, previousFactor), origin)
            previousFactor = factor
        case .ended:
            update(.completed, 1, origin)
            previousFactor = 1
        case .cancelled, .failed:
            update(.canceled, 1, origin)
            previousFactor = 1
        default:
            break
        }
    }
}

/// Pointer tracking that can sit on any native control without replacing it
/// or intercepting its button action.
@MainActor
final class AppKitPointerRecognizer: NSGestureRecognizer {
    enum Report {
        case entered
        case exited
        case moved
        case pressed
        case released
    }

    var onReport: ((Report, NSPoint?) -> Void)?
    private weak var trackedView: NSView?
    private var trackingArea: NSTrackingArea?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delaysPrimaryMouseButtonEvents = false
    }

    convenience init(onReport: @escaping (Report, NSPoint?) -> Void) {
        self.init(target: nil, action: nil)
        self.onReport = onReport
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

    @objc func mouseEntered(with event: NSEvent) {
        onReport?(.entered, nil)
    }

    @objc func mouseExited(with event: NSEvent) {
        onReport?(.exited, nil)
    }

    @objc func mouseMoved(with event: NSEvent) {
        onReport?(.moved, point(in: event))
    }

    override func mouseDown(with event: NSEvent) {
        onReport?(.pressed, point(in: event))
        state = .began
    }

    override func mouseDragged(with event: NSEvent) {
        onReport?(.moved, point(in: event))
        state = .changed
    }

    override func mouseUp(with event: NSEvent) {
        onReport?(.released, point(in: event))
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

    func emitForTesting(_ report: Report, point: NSPoint? = nil) {
        onReport?(report, point)
    }

    private func point(in event: NSEvent) -> NSPoint? {
        trackedView.map { $0.convert(event.locationInWindow, from: nil) }
    }
}

#endif
