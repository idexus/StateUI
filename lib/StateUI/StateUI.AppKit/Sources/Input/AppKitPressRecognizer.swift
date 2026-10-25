// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A press on a view that hears taps, followed as a button follows one: from the mouse's press to its release, each
/// phase told with where the pointer stands in the view. It recognizes nothing, so it keeps no other gesture from the
/// press; one begun on a control inside - a button, a field - or on a view hearing its own taps is that one's.
/// Design: docs/design/platforms/appkit/input.md#a-press-as-a-button-takes-it
@MainActor
final class AppKitPressRecognizer: NSGestureRecognizer {
    private var hearing: AppKitHearing?

    /// Whether a press stands.
    private var pressing = false

    convenience init(hearing: @escaping AppKitHearing) {
        self.init(target: nil, action: nil)
        self.hearing = hearing
        delaysPrimaryMouseButtonEvents = false
    }

    override func mouseDown(with event: NSEvent) {
        guard !pressing, isOwn(event) else { return }
        pressing = true
        press(.began, at: point(of: event))
    }

    override func mouseDragged(with event: NSEvent) {
        if pressing { press(.changed, at: point(of: event)) }
    }

    override func mouseUp(with event: NSEvent) {
        guard pressing else { return }
        pressing = false
        press(.ended, at: point(of: event))
        state = .failed
    }

    /// Another gesture took the press: it is taken away.
    override func reset() {
        if pressing {
            pressing = false
            press(.cancelled, at: Point(x: 0, y: 0))
        }
        super.reset()
    }

    /// The press at `phase`, at `point` in the view from its top left corner.
    func press(_ phase: GesturePhase, at point: Point) {
        guard let view else { return }
        let size = LayoutSize(width: Double(view.bounds.width), height: Double(view.bounds.height))
        hearing?(.press(phase, at: point, size: size, byFinger: false))
    }

    /// Where `event` stands in the view, from its top left corner.
    private func point(of event: NSEvent) -> Point {
        guard let view else { return Point(x: 0, y: 0) }
        let at = location(in: view)
        return Point(x: Double(at.x), y: Double(view.isFlipped ? at.y : view.bounds.height - at.y))
    }

    /// Whether the press `event` begins is the view's own: not one on a control inside it, nor on a view inside it that
    /// hears its own taps; one on the parts of a view that is a control is its own.
    private func isOwn(_ event: NSEvent) -> Bool {
        guard let view, !(view is NSControl), let superview = view.superview else { return true }
        var each = view.hitTest(superview.convert(event.locationInWindow, from: nil))
        while let inner = each, inner !== view {
            if inner is NSControl || inner.gestureRecognizers.contains(where: { $0 is AppKitPressRecognizer }) {
                return false
            }
            each = inner.superview
        }
        return true
    }
}

#endif
