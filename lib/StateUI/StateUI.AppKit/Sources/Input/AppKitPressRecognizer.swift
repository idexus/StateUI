// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A press on a view that hears taps, followed as a button follows one: from the mouse's press to its release, each
/// phase told with where the pointer stands in the view. It recognizes nothing, so it keeps no other gesture from the
/// press; one begun on a control inside that a click works - a button, a field - or on a view hearing its own taps is
/// that one's, while one on a label's words or a picture, which only show, is the view's.
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
        guard !pressing, isOwn(event), let at = point(of: event) else { return }
        pressing = true
        press(.began, at: at)
    }

    override func mouseDragged(with event: NSEvent) {
        guard pressing else { return }
        if let at = point(of: event) { press(.changed, at: at) } else { takenAway() }
    }

    override func mouseUp(with event: NSEvent) {
        guard pressing else { return }
        if let at = point(of: event) {
            pressing = false
            press(.ended, at: at)
        } else {
            takenAway()
        }
        state = .failed
    }

    /// Another gesture took the press: it is taken away.
    override func reset() {
        takenAway()
        super.reset()
    }

    /// The press under way, if one, is taken away: by another gesture, or by the view flattened under it.
    private func takenAway() {
        guard pressing else { return }
        pressing = false
        press(.cancelled, at: Point(x: 0, y: 0))
    }

    /// The press at `phase`, at `point` in the view from its top left corner.
    func press(_ phase: GesturePhase, at point: Point) {
        guard let view else { return }
        let size = LayoutSize(width: Double(view.bounds.width), height: Double(view.bounds.height))
        hearing?(.press(phase, at: point, size: size, byFinger: false))
    }

    /// Where `event` stands in the view, where the view is drawn, from its top left corner; nil where no point lands
    /// in the view, flattened by its drawing.
    private func point(of event: NSEvent) -> Point? {
        guard let view else { return nil }
        return view.drawnPoint(fromWindow: event.locationInWindow).map(view.topLeft)
    }

    /// Whether the press `event` begins is the view's own: not one on a control inside it a click works, nor on a
    /// view inside it that hears its own taps; one on the parts of a view that is a control is its own.
    private func isOwn(_ event: NSEvent) -> Bool {
        guard let view, !(view is NSControl), let superview = view.superview else { return true }
        guard let above = superview.drawnPoint(fromWindow: event.locationInWindow), let place = view.undrawn(above)
        else { return false }
        var each = view.hitTest(place)
        while let inner = each, inner !== view {
            if Self.takesItsOwnPress(inner) { return false }
            each = inner.superview
        }
        return true
    }

    /// Whether `inner` takes a press of its own: a view hearing its own taps, or an enabled control a click works -
    /// not a label's text field nor a picture, which AppKit makes controls though they only show.
    private static func takesItsOwnPress(_ inner: NSView) -> Bool {
        if inner.gestureRecognizers.contains(where: { $0 is AppKitPressRecognizer }) { return true }
        guard let control = inner as? NSControl, control.isEnabled else { return false }
        if let field = control as? NSTextField { return field.isEditable || field.isSelectable }
        if let picture = control as? NSImageView { return picture.isEditable }
        return true
    }
}

#endif
