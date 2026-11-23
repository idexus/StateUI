// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The hand over a layout as AppKit tells it: a pointer dragged, a trackpad's or a mouse's fingers as a scroll
/// gesture - its momentum swallowed where the gesture was the layout's, as the layout throws the run itself - and a
/// wheel's notches. Whose a gesture is, the host layer decides by its first move.
/// Design: docs/design/platforms/appkit/input.md#the-hand-over-a-layout
@MainActor
final class AppKitHandReader {
    /// The element hearing what the reader says, answering whether it took it.
    private let taking: (HeardInput) -> Bool

    /// Whether the element's hand takes a press whose first move is the one given, by the host layer's rule.
    private let takesFirst: (Point) -> Bool

    /// Whether the last gesture was the layout's: its momentum is too.
    private var tookLast = false

    /// The pointer drag the reader hears beside the scroll gestures.
    let dragging: AppKitHandDrag

    /// A reader handing what it hears to `taking`, its drag beginning where `takesFirst` takes the first move -
    /// any move, unless said.
    init(taking: @escaping (HeardInput) -> Bool, takesFirst: @escaping (Point) -> Bool = { _ in true }) {
        self.takesFirst = takesFirst
        self.taking = taking
        dragging = AppKitHandDrag()
        dragging.reader = self
    }

    /// Whether the pointer's drag begins with its first move `first`: where the host layer's rule takes it. A
    /// move it declines is told all the same - the drag tells nothing of the press after it, which would stand
    /// still for the host layer and hold a view.
    /// Design: docs/design/platforms/appkit/input.md#the-hand-over-a-layout
    func begins(first: Point) -> Bool {
        let begins = takesFirst(first)
        if !begins { hand(.changed, moved: first) }
        return begins
    }

    /// The hand at `phase`, having moved what is under it by `moved` since the last, lifting at `speed` where the
    /// platform tells one, at `time` where it says when, a press going down at `point` of the view: the host's entry,
    /// the pointer's and the trackpad's alike. Whether the layout took it.
    @discardableResult
    func hand(
        _ phase: GesturePhase, moved: Point, speed: Point? = nil, at time: Double? = nil, point: Point? = nil
    ) -> Bool {
        let took = taking(.hand(phase, moved: moved, speed: speed, at: time, point: point))
        if phase == .ended || phase == .cancelled { tookLast = took }
        return took
    }

    /// A wheel's notches over the layout, as many as it turned, across and down: the host's entry. Whether the
    /// layout took them.
    @discardableResult
    func notched(_ notches: Point) -> Bool {
        taking(.notch(notches))
    }

    /// A scroll event over the layout: a gesture's step, its momentum, or a wheel's notches - a wheel that turns
    /// notch by notch tells no precise deltas. Whether the layout took it.
    func scrolled(_ event: NSEvent) -> Bool {
        let moved = Point(x: Double(event.scrollingDeltaX), y: Double(event.scrollingDeltaY))
        // The event's own time is on the frame clock's: seconds since the system started.
        let time = event.timestamp * 1_000

        if !event.momentumPhase.isEmpty { return tookLast }
        guard !event.phase.isEmpty else { return event.hasPreciseScrollingDeltas ? taking(.wheel(moved)) : notched(moved) }
        if event.phase.contains(.mayBegin) { return false }

        if event.phase.contains(.began) { hand(.began, moved: .zero, at: time) }
        if event.phase.contains(.ended) { return hand(.ended, moved: .zero, at: time) }
        if event.phase.contains(.cancelled) { return hand(.cancelled, moved: .zero, at: time) }

        return hand(.changed, moved: moved, at: time)
    }
}

/// The pointer dragged over a layout: AppKit's drag recognizer, the press where it goes down, its moves since the
/// last and its speed at the lift handed to the reader, from the top left - the press's end told even where it never
/// moved, as a press that held a view lets it go.
@MainActor
final class AppKitHandDrag: NSPanGestureRecognizer, NSGestureRecognizerDelegate {
    weak var reader: AppKitHandReader?

    /// Where the drag had come to at its last report, where the press went down, whether it moved as a drag, and
    /// whether the press is two fingers' rather than the hand's.
    private var last = Point.zero
    private var down = Point.zero

    /// Where the pointer pressed went down and stood at its last move, in the view the hand is measured in: what the
    /// drag's first move is read from.
    private var start = Point.zero
    private var latest = Point.zero
    private var dragged = false

    /// The view the hand is measured in, which the hand does not move: the layout placing the view, else the view
    /// above it.
    /// Design: docs/design/host/interaction.md#where-the-hand-is-measured
    var handSpace: (() -> NSView?)?
    private var measured: NSView? { handSpace?() ?? view?.superview ?? view }
    private var mirrors = false

    /// The hand as the host was told it.
    private var gesture = ToldGesture()

    init() {
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized(_:))
        delaysPrimaryMouseButtonEvents = false
        delegate = self
    }

    /// AppKit's drag begins only where the view's hand takes the press's first move - the way its values go, the
    /// way its own drag begins, any way where it holds the view: a move it leaves is the hand's of what holds
    /// the view, whose drag AppKit would not begin beside this one.
    func gestureRecognizerShouldBegin(_ recognizer: NSGestureRecognizer) -> Bool {
        // AppKit asks before its drag has a translation: the first move is read off the press itself.
        reader?.begins(first: Point(x: latest.x - start.x, y: latest.y - start.y)) ?? true
    }

    override func mouseDragged(with event: NSEvent) {
        if let at = point(of: event, in: measured) { latest = at }
        super.mouseDragged(with: event)
    }

    /// The hand of a view waits for the hand of a view inside it: the innermost that takes the press has it.
    override func shouldRequireFailure(of other: NSGestureRecognizer) -> Bool {
        guard let inner = (other as? AppKitHandDrag)?.view, let view, inner !== view else { return false }
        return inner.isDescendant(of: view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitHandDrag is created in code")
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // A press with ⌥ over a view two fingers move is theirs.
        mirrors = AppKitMirroredRecognizer.takes(event.modifierFlags)
            && view?.gestureRecognizers.contains { $0 is AppKitMirroredRecognizer } == true
        guard !mirrors else { return }
        guard let at = point(of: event, in: view) else { return takenAway(at: .began) }
        pressed(at: at)
        if let here = point(of: event, in: measured) { (start, latest) = (here, here) }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard !dragged, !mirrors, gesture.isUnderWay else { return }
        if point(of: event, in: view) == nil { takenAway(at: .ended) } else { released() }
    }

    /// The pointer pressed at `point` of the view: the hand begins there.
    func pressed(at point: Point) {
        down = point
        (start, latest) = (point, point)
        last = .zero
        dragged = false
        gesture.told(.began)
        reader?.hand(.began, moved: .zero, point: point)
    }

    /// The view is flattened under the hand at `phase`: the press under way, if one, is taken away, and nothing more
    /// of it is told.
    private func takenAway(at phase: GesturePhase) {
        guard gesture.takeAway(at: phase) else { return }
        gesture.told(.cancelled)
        reader?.hand(.cancelled, moved: .zero)
    }

    /// The pointer pressed moved to `point` of the view, as the drag tells it.
    func moved(to point: Point) {
        let total = Point(x: point.x - down.x, y: point.y - down.y)
        reader?.hand(.changed, moved: Point(x: total.x - last.x, y: total.y - last.y))
        last = total
        dragged = true
    }

    /// The pointer pressed let go, at the speed the drag read where it moved.
    func released(speed: Point? = nil) {
        gesture.told(.ended)
        reader?.hand(.ended, moved: .zero, speed: speed)
    }

    /// Where `event` happened in `space`, where it is drawn, from its top left; nil where no point lands in it,
    /// flattened by its drawing.
    private func point(of event: NSEvent, in space: NSView?) -> Point? {
        guard let space else { return nil }
        return space.drawnPoint(fromWindow: event.locationInWindow).map(space.topLeft)
    }

    @objc private func recognized(_ recognizer: NSPanGestureRecognizer) {
        recognized(state, at: location(in: nil), moved: translation(in: nil), speed: velocity(in: measured))
    }

    /// AppKit's drag at `state`, the press at `now` of the window, having moved by `moved` there since it began, at
    /// `speed` in the points of the view the hand is measured in.
    func recognized(_ state: NSGestureRecognizer.State, at now: NSPoint, moved: NSPoint, speed: NSPoint = .zero) {
        // The press began the hand: the drag's beginning is a step of it.
        guard let view, let space = measured,
              let phase = GesturePhase(state).map({ $0 == .began ? GesturePhase.changed : $0 }), gesture.tells(phase)
        else { return }
        // How far the press came, measured in a view the hand does not move; a view flattened under it takes it away.
        guard view.drawnPoint(fromWindow: now) != nil, let at = space.drawnPoint(fromWindow: now).map(space.topLeft),
              let from = space.drawnPoint(fromWindow: NSPoint(x: now.x - moved.x, y: now.y - moved.y)).map(space.topLeft)
        else { return takenAway(at: phase) }
        let total = Point(x: at.x - from.x, y: at.y - from.y)

        switch state {
        case .began:
            reader?.hand(.changed, moved: total)
            last = total
            dragged = true
        case .changed:
            reader?.hand(.changed, moved: Point(x: total.x - last.x, y: total.y - last.y))
            last = total
        case .ended:
            released(speed: Point(x: Double(speed.x), y: Double(space.isFlipped ? speed.y : -speed.y)))
        case .cancelled, .failed:
            gesture.told(.cancelled)
            reader?.hand(.cancelled, moved: .zero)
        default:
            break
        }
    }
}
#endif
