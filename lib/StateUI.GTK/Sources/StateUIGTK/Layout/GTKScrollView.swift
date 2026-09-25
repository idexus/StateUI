// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A ScrollView: a StateUI layout holding GTK's own scroller around the document it moves.
/// Design: docs/design/platforms/gtk/layout.md#scrolling
@MainActor
final class GTKScrollView: GTKLayoutView {
    /// Says, on a display frame, where the user moved the scroller from and to.
    var onOffsetChanged: ((Point, Point) -> Void)?

    /// Says, on a display frame, that the user's movement came to rest.
    var onScrollStopped: (() -> Void)?

    /// Asks for the display's frames: the scroller moves, or has something to say.
    var onFramesWanted: (() -> Void)?

    private(set) var orientation = ScrollOrientation.vertical

    /// Where the scroller stands, as it last said.
    private(set) var offset = Point(x: 0, y: 0)

    /// The user's movement, and its rest.
    private let movement = ScrollMovement()

    let scroller = GTKScrollerView()
    private let document = GTKScrollDocument()

    /// Holds the content in a stack where the scroller was given more than one child.
    private let wrapper = GTKStackView(axis: .vertical)
    private var wraps = false

    /// An offset the tree wrote before the scroller was laid out, and whether it has been.
    private var pendingOffset: Point?
    private var laidOut = false

    private var bars = (vertical: ScrollBarVisibility.default, horizontal: ScrollBarVisibility.default)

    override init() {
        super.init()
        movement.onFramesWanted = { [weak self] in self?.onFramesWanted?() }
        scroller.onScrolled = { [weak self] standing in self?.scrolled(to: standing) }
        scroller.onHeld = { [weak self] holding in self?.scrollerHeld(holding) }
        scroller.placingLayout = self
        setChildren([scroller])
        configure()
    }

    /// The content: one child, or several stacked down.
    @discardableResult
    override func setItems(_ items: [GTKLayoutItem]) -> Bool {
        if items.count > 1 { wraps = true }

        var changed = false
        if wraps {
            changed = wrapper.setItems(items)
            changed = document.setItems([GTKLayoutItem(view: wrapper)]) || changed
        } else {
            changed = document.setItems(items)
        }
        if changed { invalidateMeasurements() }
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
        if orientation != self.orientation || verticalBar != bars.vertical || horizontalBar != bars.horizontal {
            self.orientation = orientation
            bars = (verticalBar, horizontalBar)
            configure()
        }
        document.padding = padding
        document.orientation = orientation

        guard let target = ScrollArithmetic.offsetWritten(offset, standing: self.offset, orientation: orientation)
        else { return }
        if laidOut || orientation == .neither { move(to: target) } else { pendingOffset = target }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        document.contentSize(width: width)
    }

    /// Stands GTK's scroller over the whole of the room, then an offset the tree wrote before there was one.
    override func arrange(in bounds: Rect) {
        scroller.layout(bounds)
        laidOut = true

        if let pendingOffset {
            self.pendingOffset = nil
            move(to: pendingOffset)
        }
    }

    // MARK: - The user's movement

    /// The scroller's view changed: the user's move, joined to the moves before it until the display's next frame;
    /// the program's own move is its write's echo.
    private func scrolled(to standing: Point) {
        guard !ProgramWrite.isWriting, standing != offset else { return }

        let previous = offset
        offset = standing
        movement.userMoved(from: previous, to: standing)
    }

    /// The user took hold of the scroller, or let go of it and left it to throw on.
    private func scrollerHeld(_ holding: Bool) {
        if holding {
            movement.holdBegan()
        } else {
            movement.holdEnded(rests: false)
        }
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
        super.detach()
        onOffsetChanged = nil
        onScrollStopped = nil
        onFramesWanted = nil
        scroller.detach()
    }

    private func configure() {
        scroller.set(
            content: document, orientation: orientation, verticalBar: bars.vertical, horizontalBar: bars.horizontal)
    }

    /// Moves the scroller to `target`, kept within what it reaches, as the program's move.
    private func move(to target: Point) {
        let standing = scroller.standing
        let kept = ScrollArithmetic.kept(target, reach: standing.reach)
        offset = kept
        guard ScrollArithmetic.differs(kept, standing.offset) else { return }

        ProgramWrite.perform { scroller.move(to: kept) }
    }
}
