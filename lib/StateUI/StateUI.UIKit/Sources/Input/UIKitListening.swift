// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One view's listening: a UIKit gesture recognizer for each kind of input the view listens for, what each heard
/// told in the contract's terms (`HeardInput`), a press dragged and a pinch read by the host layer's rules.
/// Design: docs/design/platforms/uikit/input.md
@MainActor
final class UIKitListening: NSObject, UIGestureRecognizerDelegate {
    private weak var view: UIView?

    /// What the view listens for.
    private(set) var hearing: Hearing = []

    /// What hears what the view heard, answering whether the element took it.
    var onHeard: ((HeardInput) -> Bool)?

    /// Which way the hand moves the layout the view is, where one does.
    var handAxis: (() -> LayoutInput.Axis?)?

    /// The hand over a layout, and where it had come to at its last report.
    private var handPan: UIPanGestureRecognizer?
    private var handLast = CGPoint.zero

    private var recognizers: [Hearing: [UIGestureRecognizer]] = [:]

    /// The place in its quick run of the tap the tap recognizer follows, as the touch counts it.
    var tapRun = 1

    /// The press dragged, by the host layer's rule, on the window; and the pinch's steps.
    private var drag = DragRecognition(distance: .eachAxis(x: 0, y: 0))
    private var pinch = PinchStep()

    init(view: UIView) {
        self.view = view
    }

    /// Listens for what `hearing` names: a kind newly asked for gets its recognizers, one no longer asked for loses
    /// them. A view that listens takes touches, as a label and a picture do not of themselves.
    func listen(for hearing: Hearing) {
        guard let view else { return }
        for kind in Hearing.kinds where hearing.contains(kind) != self.hearing.contains(kind) {
            if hearing.contains(kind) {
                let made = recognizers(for: kind)
                for recognizer in made {
                    recognizer.delegate = self
                    view.addGestureRecognizer(recognizer)
                }
                recognizers[kind] = made
            } else {
                for recognizer in recognizers[kind] ?? [] { view.removeGestureRecognizer(recognizer) }
                recognizers[kind] = nil
                if kind == .hand { handPan = nil }
            }
        }
        self.hearing = hearing
    }

    private func recognizers(for kind: Hearing) -> [UIGestureRecognizer] {
        switch kind {
        case .taps: return [UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))]
        case .pointer:
            let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
            press.minimumPressDuration = 0
            press.allowableMovement = .greatestFiniteMagnitude
            press.cancelsTouchesInView = false
            return [UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:))), press]
        case .drags:
            let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
            pan.maximumNumberOfTouches = 1
            return [pan]
        case .hand:
            // A finger, a trackpad's two fingers and a wheel: one pan.
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handMoved(_:)))
            pan.allowedScrollTypesMask = .all
            handPan = pan
            return [pan]
        default: return [UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))]
        }
    }

    private func tell(_ heard: HeardInput) {
        _ = onHeard?(heard)
    }

    // MARK: - Taps

    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        tell(.tap(run: tapRun))
    }

    // MARK: - The pointer

    @objc func hovered(_ recognizer: UIHoverGestureRecognizer) {
        let point = location(of: recognizer)
        switch recognizer.state {
        case .began: tell(.pointer(.pointerEntered, point))
        case .changed: tell(.pointer(.pointerMoved, point))
        case .ended, .cancelled, .failed: tell(.pointer(.pointerExited, Point(x: 0, y: 0)))
        default: break
        }
    }

    @objc func pressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began: tell(.pointer(.pointerPressed, location(of: recognizer)))
        case .ended, .cancelled: tell(.pointer(.pointerReleased, location(of: recognizer)))
        default: break
        }
    }

    // MARK: - A press dragged

    /// A pan UIKit recognized past its own distance: its press put back where it went down, on the window, which
    /// the view it moves does not move.
    /// Design: docs/design/platforms/uikit/input.md#a-press-dragged
    @objc func dragged(_ recognizer: UIPanGestureRecognizer) {
        let window = view?.window
        let now = recognizer.location(in: window)
        switch recognizer.state {
        case .began:
            let moved = recognizer.translation(in: window)
            drag = DragRecognition(distance: .eachAxis(x: 0, y: 0))
            drag.pressed(at: Point(x: now.x - moved.x, y: now.y - moved.y))
            drag.moved(to: Point(x: now.x, y: now.y)).forEach(tell)
        case .changed:
            drag.moved(to: Point(x: now.x, y: now.y)).forEach(tell)
        case .ended:
            if let end = drag.ended(letGo: true) { tell(end) }
        case .cancelled, .failed:
            if let end = drag.ended(letGo: false) { tell(end) }
        default: break
        }
    }

    // MARK: - The hand over a layout

    /// The hand over a layout: what it moved since the last report, from the top left, and as it lifts, its speed.
    /// Design: docs/design/platforms/uikit/input.md#the-hand-over-a-layout
    @objc func handMoved(_ recognizer: UIPanGestureRecognizer) {
        let total = recognizer.translation(in: view)
        switch recognizer.state {
        case .began:
            hand(.began, moved: .zero)
            hand(.changed, moved: Point(x: total.x, y: total.y))
            handLast = total
        case .changed:
            hand(.changed, moved: Point(x: total.x - handLast.x, y: total.y - handLast.y))
            handLast = total
        case .ended:
            let speed = recognizer.velocity(in: view)
            hand(.ended, moved: .zero, speed: Point(x: speed.x, y: speed.y))
        case .cancelled, .failed:
            hand(.cancelled, moved: .zero)
        default: break
        }
    }

    /// The hand at `phase`, having moved what is under it by `moved`, lifting at `speed`: the host's entry. Whether
    /// the layout took it.
    @discardableResult
    func hand(_ phase: GesturePhase, moved: Point, speed: Point? = nil) -> Bool {
        onHeard?(.hand(phase, moved: moved, speed: speed)) ?? false
    }

    /// The hand over a layout begins only moving along the layout's axis - its first move or, from a trackpad or a
    /// wheel that tells none yet, its speed - by the host layer's rule.
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer === handPan, let pan = handPan else { return true }
        guard let axis = handAxis?() else { return false }

        let moved = pan.translation(in: view)
        let first = moved == .zero ? pan.velocity(in: view) : moved
        return HandReading.claims(Point(x: first.x, y: first.y), along: axis)
    }

    // MARK: - A pinch

    /// A pinch's step: its scale since the last, and where, as shares of the view's size.
    @objc func pinched(_ recognizer: UIPinchGestureRecognizer) {
        let phase: GesturePhase
        switch recognizer.state {
        case .began: phase = .began
        case .changed: phase = .changed
        case .ended, .cancelled, .failed: phase = .ended
        default: return
        }
        let step = pinch.step(phase, scale: phase == .changed ? recognizer.scale : 1)
        let size = view?.bounds.size ?? .zero
        let at = PinchStep.share(of: location(of: recognizer), width: size.width, height: size.height)
        tell(.pinch(phase, scale: step, at: at))
    }

    // MARK: - Recognizers together

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if recognizer is UITapGestureRecognizer { tapRun = max(1, touch.tapCount) }
        return true
    }

    /// Every recognizer hears with the others but a stack's swipe back from within its page, which a drag comes
    /// before.
    /// Design: docs/design/platforms/uikit/input.md#a-press-dragged
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // The hand over a layout is the layout's alone: a scroller holding it does not move with it.
        if recognizer === handPan, other is UIPanGestureRecognizer { return false }
        return !isSwipeBack(other)
    }

    /// A scroller holding a layout waits for the layout's hand to fail - as it does for a gesture across its axis.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        if recognizer === handPan, let scroller = other.view as? UIScrollView, other === scroller.panGestureRecognizer {
            return true
        }
        return recognizer is UIPanGestureRecognizer && isSwipeBack(other)
    }

    /// Whether `other` is the swipe back from within the page of the stack the view stands in.
    private func isSwipeBack(_ other: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = view
        while let each = responder {
            if let stack = each as? UINavigationController { return other === stack.interactiveContentPopGestureRecognizer }
            responder = each.next
        }
        return false
    }

    /// Where the recognizer's touch is, in points of the view.
    private func location(of recognizer: UIGestureRecognizer) -> Point {
        let point = recognizer.location(in: view)
        return Point(x: point.x, y: point.y)
    }

    /// Lets go of every recognizer, as the element leaves.
    func detach() {
        listen(for: [])
        onHeard = nil
    }
}
#endif
