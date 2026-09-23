// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A ScrollView: a StateUI layout holding Android's own scroller - a `ScrollView`, a `HorizontalScrollView`,
/// or the second inside the first for both - around the document it moves.
/// Design: docs/design/platforms/android/layout.md#scrolling
@MainActor
final class AndroidScrollView: AndroidLayoutView {
    /// Says, on a display frame, where the user moved the scroller from and to, in points.
    var onOffsetChanged: ((Point, Point) -> Void)?

    /// Says, on a display frame, that the user's movement came to rest.
    var onScrollStopped: (() -> Void)?

    /// Asks for the display's frames: the scroller moves, or has something to say.
    var onFramesWanted: (() -> Void)?

    private(set) var orientation = ScrollOrientation.vertical

    /// Where the scroller stands, in points, as it was last seen.
    private(set) var offset = Point(x: 0, y: 0)

    /// The user's movement, and its rest.
    private let movement = ScrollMovement()

    private let document = AndroidScrollDocument()

    /// Holds the content in a stack where the scroller was given more than one child.
    private let wrapper = AndroidStackView(axis: .vertical)
    private var wraps = false

    /// Android's scrollers, the outermost first; the last holds the document.
    private(set) var scrollers: [JavaObject] = []

    /// An offset the tree wrote before the scrollers were laid out, and whether they have been.
    private var pendingOffset: Point?
    private var laidOut = false

    /// Cuts what it scrolls off at its edges, where every other StateUI layout draws past them.
    override init() {
        super.init()
        Java.call(reference, JavaAPI.setClipChildren, .bool(true))
        movement.onFramesWanted = { [weak self] in self?.onFramesWanted?() }
        build()
    }

    /// The content: one child, or several stacked down.
    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        if items.count > 1 { wraps = true }

        var changed = false
        if wraps {
            changed = wrapper.setItems(items)
            changed = document.setItems([AndroidLayoutItem(view: wrapper)]) || changed
        } else {
            changed = document.setItems(items)
        }
        if changed { forgetMeasurements() }
        return changed
    }

    override func forgetMeasurements() {
        super.forgetMeasurements()
        document.forgetMeasurements()
        wrapper.forgetMeasurements()
    }

    /// The scroller's orientation, padding, bars, and an offset the tree moved it to.
    func apply(
        orientation: ScrollOrientation, padding: Insets, verticalBar: ScrollBarVisibility,
        horizontalBar: ScrollBarVisibility, offset: Point?
    ) {
        if orientation != self.orientation {
            self.orientation = orientation
            build()
        }
        document.padding = padding
        document.orientation = orientation

        for scroller in scrollers {
            Java.call(scroller.reference, JavaAPI.setVerticalScrollBarEnabled, .bool(verticalBar != .never))
            Java.call(scroller.reference, JavaAPI.setHorizontalScrollBarEnabled, .bool(horizontalBar != .never))
            Java.call(
                scroller.reference, JavaAPI.setScrollbarFadingEnabled,
                .bool(verticalBar != .always && horizontalBar != .always))
        }

        guard orientation != .neither else { return move(to: Point(x: 0, y: 0)) }
        guard let offset, offset.x.isFinite, offset.y.isFinite else { return }

        // The user's own scrolling comes back as the state it wrote: a scroller already there is left alone.
        if abs(offset.x - self.offset.x) < 0.5, abs(offset.y - self.offset.y) < 0.5 { return }
        if laidOut { move(to: offset) } else { pendingOffset = offset }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        document.contentSize(width: width)
    }

    /// Stands Android's scroller over the whole of the room, then an offset the tree wrote before there was one.
    override func arrange(width: Int32, height: Int32) {
        guard let outer = scrollers.first else { return }

        Java.call(
            outer.reference, JavaAPI.measure,
            .int(ViewConstants.spec(ViewConstants.exactly, width)),
            .int(ViewConstants.spec(ViewConstants.exactly, height)))
        Java.call(outer.reference, JavaAPI.layout, .int(0), .int(0), .int(width), .int(height))
        laidOut = true

        if let pendingOffset {
            self.pendingOffset = nil
            move(to: pendingOffset)
        }
    }

    // MARK: - The user's movement

    /// Android moved the scroller: where to, joined to the moves before it until the display's next frame.
    func scrolled() {
        guard !ProgramWrite.isWriting else { return }

        let standing = standingOffset
        guard standing != offset else { return }
        let previous = offset
        offset = standing
        movement.userMoved(from: previous, to: standing)
    }

    /// A finger took hold of the scroller, or let go of it and left it to throw on.
    func held(_ holding: Bool) {
        if holding { movement.holdBegan() } else { movement.holdEnded(rests: false) }
    }

    /// Whether the scroller needs the display's frames.
    var wantsFrames: Bool { movement.wantsFrames }

    /// One frame of the display: what the scroller has to say, said here and nowhere else.
    func frame(now: Double) {
        for report in movement.frame(now: now) {
            switch report {
            case .moved(let from, let to): onOffsetChanged?(from, to)
            case .rested: onScrollStopped?()
            }
        }
    }

    override func detach() {
        onOffsetChanged = nil
        onScrollStopped = nil
        onFramesWanted = nil
    }

    // MARK: - Android's scrollers

    /// The scroller moving down, and the one moving across; nil where the orientation has none.
    private var vertical: JavaObject? { orientation == .horizontal ? nil : scrollers.first }
    private var horizontal: JavaObject? {
        orientation == .horizontal || orientation == .both ? scrollers.last : nil
    }

    /// Where Android's scrollers stand, in points.
    private var standingOffset: Point {
        Point(
            x: horizontal.map { Double(Java.callInt($0.reference, JavaAPI.getScrollX)) / density } ?? 0,
            y: vertical.map { Double(Java.callInt($0.reference, JavaAPI.getScrollY)) / density } ?? 0)
    }

    /// Moves Android's scrollers to `target` as the program's write; each keeps it within what it can reach.
    private func move(to target: Point) {
        ProgramWrite.perform {
            if let vertical { Java.call(vertical.reference, JavaAPI.scrollTo, .int(0), .int(pixels(target.y))) }
            if let horizontal { Java.call(horizontal.reference, JavaAPI.scrollTo, .int(pixels(target.x)), .int(0)) }
        }
        offset = standingOffset
    }

    /// Makes the scrollers the orientation asks for, each listened to, the document in the innermost.
    private func build() {
        Java.call(reference, JavaAPI.removeAllViews)
        if let parent = Java.callObject(document.reference, JavaAPI.getParent) {
            Java.call(parent, JavaAPI.removeView, .object(document.reference))
            Java.release(local: parent)
        }

        let kinds: [Bool] = switch orientation {
        case .horizontal: [false]
        case .both: [true, false]
        default: [true]
        }
        scrollers = kinds.map { downward in
            let scroller = downward
                ? Java.new(JavaAPI.scrollView, JavaAPI.newScrollView, .object(AndroidRenderer.context))
                : Java.new(JavaAPI.horizontalScrollView, JavaAPI.newHorizontalScrollView, .object(AndroidRenderer.context))
            Java.call(
                scroller.reference, downward ? JavaAPI.setFillViewport : JavaAPI.setHorizontalFillViewport, .bool(true))
            listen(on: scroller.reference, JavaAPI.setOnScrollChangeListener, JavaAPI.setOnTouchListener)
            return scroller
        }

        for (outer, inner) in zip(scrollers, scrollers.dropFirst()) {
            Java.call(outer.reference, JavaAPI.addView, .object(inner.reference), .int(-1), .int(-1))
        }
        Java.call(scrollers.last!.reference, JavaAPI.addView, .object(document.reference), .int(-1), .int(-1))
        Java.call(reference, JavaAPI.addView, .object(scrollers[0].reference), .int(-1), .int(-1))
        offset = Point(x: 0, y: 0)
        laidOut = false
    }
}
