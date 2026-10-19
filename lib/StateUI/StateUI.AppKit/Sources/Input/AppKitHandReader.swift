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

    /// Whether the last gesture was the layout's: its momentum is too.
    private var tookLast = false

    /// The pointer drag the reader hears beside the scroll gestures.
    let dragging: AppKitHandDrag

    init(taking: @escaping (HeardInput) -> Bool) {
        self.taking = taking
        dragging = AppKitHandDrag()
        dragging.reader = self
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
        let moved = Point(Double(event.scrollingDeltaX), Double(event.scrollingDeltaY))
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
final class AppKitHandDrag: NSPanGestureRecognizer {
    weak var reader: AppKitHandReader?

    /// Where the drag had come to at its last report, where the press went down, whether it moved as a drag, and
    /// whether the press is two fingers' rather than the hand's.
    private var last = Point.zero
    private var down = Point.zero
    private var dragged = false
    private var mirrors = false

    init() {
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized(_:))
        delaysPrimaryMouseButtonEvents = false
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
        pressed(at: point(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if !dragged, !mirrors { released() }
    }

    /// The pointer pressed at `point` of the view: the hand begins there.
    func pressed(at point: Point) {
        down = point
        last = .zero
        dragged = false
        reader?.hand(.began, moved: .zero, point: point)
    }

    /// The pointer pressed moved to `point` of the view, as the drag tells it.
    func moved(to point: Point) {
        let total = Point(point.x - down.x, point.y - down.y)
        reader?.hand(.changed, moved: Point(total.x - last.x, total.y - last.y))
        last = total
        dragged = true
    }

    /// The pointer pressed let go, at the speed the drag read where it moved.
    func released(speed: Point? = nil) {
        reader?.hand(.ended, moved: .zero, speed: speed)
    }

    /// Where `event` happened in the view, from its top left.
    private func point(of event: NSEvent) -> Point {
        guard let view else { return .zero }
        let at = view.convert(event.locationInWindow, from: nil)
        return Point(Double(at.x), Double(view.isFlipped ? at.y : view.bounds.height - at.y))
    }

    @objc private func recognized(_ recognizer: NSPanGestureRecognizer) {
        let flipped = view?.isFlipped == true
        let moved = translation(in: view)
        let total = Point(Double(moved.x), Double(flipped ? moved.y : -moved.y))

        switch state {
        case .began:
            reader?.hand(.changed, moved: total)
            last = total
            dragged = true
        case .changed:
            reader?.hand(.changed, moved: Point(total.x - last.x, total.y - last.y))
            last = total
        case .ended:
            let speed = velocity(in: view)
            released(speed: Point(Double(speed.x), Double(flipped ? speed.y : -speed.y)))
        case .cancelled, .failed:
            reader?.hand(.cancelled, moved: .zero)
        default:
            break
        }
    }
}
#endif
