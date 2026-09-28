// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// A finger's and a pointer's acts, handed to the view's listening as its recognizers would hand them - a recognizer
/// the view does not listen with hears nothing, as UIKit sends it nothing - and to a control as its own tracking
/// of the touch sends its events.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-does
extension UIKitDriver {
    /// Runs `body` with the element's view and its listening, where it listens; the view must be one.
    func touch(_ element: MountedElement, _ body: (UIKitListening?, UIView) -> Void) throws {
        guard let native = element.native as? UIKitElement, let view = native.view else {
            throw DriverCannot("touch \(element.type.name), which shows no view")
        }
        renderer?.layOut()
        body(native.listening, view)
    }

    static func tap(_ listening: UIKitListening?, on view: UIView, count: Int) {
        guard let listening, listening.hearing.contains(.taps) else { return }
        for run in 1...max(1, count) {
            let tap = DrivenTap(on: view)
            tap.point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            listening.tapRun = run
            listening.tapped(tap)
        }
    }

    /// A pan from the view's middle by `offset`, in two moves, let go where it ends.
    static func pan(_ listening: UIKitListening?, on view: UIView, by offset: Point) {
        guard let listening, listening.hearing.contains(.drags) else { return }
        let pan = DrivenPan(on: view)
        pan.start = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for (state, share) in [(UIGestureRecognizer.State.began, 0.5), (.changed, 1.0), (.ended, 1.0)] {
            pan.driven = state
            pan.point = CGPoint(x: pan.start.x + offset.x * share, y: pan.start.y + offset.y * share)
            listening.dragged(pan)
        }
    }

    /// A pinch at `share` of the view's size, spreading or closing to `scale`.
    static func pinch(_ listening: UIKitListening?, on view: UIView, by scale: Double, at share: Point) {
        guard let listening, listening.hearing.contains(.pinches) else { return }
        let pinch = DrivenPinch(on: view)
        pinch.point = CGPoint(x: view.bounds.width * share.x, y: view.bounds.height * share.y)
        for (state, scaled) in [(UIGestureRecognizer.State.began, 1.0), (.changed, scale), (.ended, scale)] {
            pinch.driven = state
            pinch.drivenScale = scaled
            listening.pinched(pinch)
        }
    }

    func pressDown(_ listening: UIKitListening?, on view: UIView, at point: Point) {
        (view as? UIControl)?.sendActions(for: .touchDown)
        (view as? UIKitCanvasView)?.pressed(at: CGPoint(x: point.x, y: point.y))
        let pan = DrivenPan(on: view)
        pan.start = CGPoint(x: point.x, y: point.y)
        pan.point = pan.start
        press = (pan, false)
        guard let listening, listening.hearing.contains(.pointer) else { return }
        let down = DrivenPress(on: view)
        down.point = pan.start
        listening.pressed(down)
    }

    func drag(_ listening: UIKitListening?, to point: Point) {
        guard let (pan, dragging) = press else { return }
        Self.track(pan.on, to: point)
        pan.point = CGPoint(x: point.x, y: point.y)
        pan.driven = dragging ? .changed : .began
        press = (pan, true)
        guard let listening, listening.hearing.contains(.drags) else { return }
        listening.dragged(pan)
    }

    func lift(_ listening: UIKitListening?, at point: Point) {
        guard let (pan, dragging) = press else { return }
        press = nil
        // A slider's thumb stands under the finger as it lifts; UIKit says no other move then.
        if pan.on is UIKitSliderView { Self.track(pan.on, to: point) }
        (pan.on as? UIControl)?.sendActions(for: .touchUpInside)
        (pan.on as? UIKitCanvasView)?.released(at: CGPoint(x: point.x, y: point.y))
        pan.point = CGPoint(x: point.x, y: point.y)
        if dragging, let listening, listening.hearing.contains(.drags) {
            pan.driven = .ended
            listening.dragged(pan)
        }
        guard let listening, listening.hearing.contains(.pointer) else { return }
        let up = DrivenPress(on: pan.on)
        up.driven = .ended
        up.point = pan.point
        listening.pressed(up)
    }

    /// A control following a finger held on it, as its own tracking does: a slider's thumb under the finger.
    private static func track(_ view: UIView, to point: Point) {
        if let canvas = view as? UIKitCanvasView { return canvas.dragged(to: CGPoint(x: point.x, y: point.y)) }
        guard let slider = view as? UIKitSliderView, slider.bounds.width > 0 else {
            (view as? UIControl)?.sendActions(for: .touchDragInside)
            return
        }
        let share = min(max(point.x / slider.bounds.width, 0), 1)
        slider.value = slider.minimumValue + Float(share) * (slider.maximumValue - slider.minimumValue)
        slider.sendActions(for: .valueChanged)
    }

    static func hover(_ listening: UIKitListening?, on view: UIView, at point: Point) {
        guard let listening, listening.hearing.contains(.pointer) else { return }
        let hover = DrivenHover(on: view)
        hover.point = CGPoint(x: point.x, y: point.y)
        for state in [UIGestureRecognizer.State.began, .changed] {
            hover.driven = state
            listening.hovered(hover)
        }
    }

    static func leave(_ listening: UIKitListening?, on view: UIView) {
        guard let listening, listening.hearing.contains(.pointer) else { return }
        let hover = DrivenHover(on: view)
        hover.driven = .ended
        listening.hovered(hover)
    }
}
