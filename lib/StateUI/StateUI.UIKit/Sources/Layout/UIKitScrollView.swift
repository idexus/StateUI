// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ScrollView: a StateUI layout holding UIKit's own scroll view around the document it moves. What the user does
/// to it is said on the display's frames, by the host layer's reading of it (`ScrollMovement`).
/// Design: docs/design/platforms/uikit/layout.md#scrolling
@MainActor
final class UIKitScrollView: UIKitLayoutView, UIScrollViewDelegate, UIKitRefreshing {
    /// Says, on a display frame, where the user moved the scroller from and to.
    var onOffsetChanged: ((Point, Point) -> Void)?

    /// Says, on a display frame, that the user's movement came to rest.
    var onScrollStopped: (() -> Void)?

    /// Asks for the display's frames: the scroller moves, or has something to say.
    var onFramesWanted: (() -> Void)?

    private(set) var orientation = ScrollOrientation.vertical

    /// Where the scroller stands, as it last said.
    var offset: Point { scrollerOffset.standing }

    /// The user's movement, and its rest.
    private let movement = ScrollMovement()

    let scroller = UIScrollView()
    private(set) lazy var refresh = UIKitRefresh(scroller)
    private let document = UIKitScrollDocument()

    /// Holds the content in a stack where the scroller was given more than one child.
    private let wrapper = UIKitStackView(axis: .vertical)
    private var wraps = false

    /// Where the scroller stands as the host knows it, and the offset the tree writes (`ScrollerOffset`).
    private var scrollerOffset = ScrollerOffset()

    /// The direction its content is laid out in, the element's: the document and the stack holding several children
    /// take it.
    override var direction: LayoutDirection {
        didSet {
            document.direction = direction
            wrapper.direction = direction
        }
    }

    override init() {
        super.init()
        movement.onFramesWanted = { [weak self] in self?.onFramesWanted?() }
        scroller.delegate = self
        scroller.contentInsetAdjustmentBehavior = .never
        scroller.addSubview(document)
        addSubview(scroller)
        configure(vertical: .automatic, horizontal: .automatic)
    }

    /// The content: one child, or several stacked down.
    override func setItems(_ items: [UIKitLayoutItem]) {
        if items.count > 1 { wraps = true }
        if wraps {
            wrapper.setItems(items)
            document.setItems([UIKitLayoutItem(view: wrapper)])
        } else {
            document.setItems(items)
        }
        forgetMeasurements()
        setNeedsLayout()
    }

    override func forgetMeasurements() {
        super.forgetMeasurements()
        document.forgetMeasurements()
        wrapper.forgetMeasurements()
    }

    /// The scroller's orientation, padding, bars, and an offset the tree moved it to.
    func apply(
        orientation: ScrollOrientation, padding: Insets, verticalBar: ScrollIndicatorVisibility,
        horizontalBar: ScrollIndicatorVisibility, offset: Point?
    ) {
        if orientation != self.orientation {
            self.orientation = orientation
            setNeedsLayout()
        }
        configure(vertical: verticalBar, horizontal: horizontalBar)
        document.padding = padding
        document.orientation = orientation

        if let target = scrollerOffset.written(offset, orientation: orientation) {
            move(to: target)
        }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        document.contentSize(width: width)
    }

    /// Stands UIKit's scroll view over the whole of the room and the document in it, then an offset the tree wrote
    /// before there was one. A frame set again, the same, pulls a stretch past the edge back within reach.
    /// Design: docs/design/platforms/uikit/layout.md#scrolling
    override func arrange(in bounds: Rect) {
        let frame = CGRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        if scroller.frame != frame { scroller.frame = frame }
        let size = document.documentSize(in: LayoutSize(width: bounds.width, height: bounds.height))
        let documentSize = CGSize(width: size.width, height: size.height)
        if document.frame.size != documentSize { document.frame = CGRect(origin: .zero, size: documentSize) }
        if scroller.contentSize != documentSize { scroller.contentSize = documentSize }
        if let target = scrollerOffset.laidOutNow() { move(to: target) }
    }

    /// What the scroller keeps clear on each edge - the bars a room's scroller reaches under - so its first and last
    /// content scroll out from under them; its offsets are counted from its first content clear of them.
    private var clearance = Clearance.none

    /// Keeps `clearance` clear, the scroller standing where the tree has it - or at its end still where it stood at
    /// its end, a move of its own told as the user's is (`ScrollArithmetic.keptAtEnd`).
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    func keepClear(_ clearance: Clearance) {
        guard clearance != self.clearance else { return }
        let (standing, before) = (toolkitStanding, reach(keeping: self.clearance))
        self.clearance = clearance
        let (top, left, bottom, right) = (clearance.top, clearance.left, clearance.bottom, clearance.right)
        scroller.contentInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        scroller.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        scroller.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: left, bottom: 0, right: right)
        let native = SafeAreaArithmetic.native(offset: standing, clearance: clearance)
        ProgramWrite.perform { scroller.contentOffset = CGPoint(x: native.x, y: native.y) }
        if let end = ScrollArithmetic.keptAtEnd(standing, reach: before, now: reach(keeping: clearance)) {
            scroller.contentOffset = self.native(of: end)
        }
    }

    /// The farthest the scroller stands keeping `clearance` clear: its content and the clearance past its viewport.
    private func reach(keeping clearance: Clearance) -> Point {
        Point(
            x: max(0, scroller.contentSize.width + clearance.left + clearance.right - scroller.bounds.width),
            y: max(0, scroller.contentSize.height + clearance.top + clearance.bottom - scroller.bounds.height))
    }

    /// The toolkit's offset for the scroller to stand at `offset`, counted from its first content kept clear.
    func native(of offset: Point) -> CGPoint {
        let native = SafeAreaArithmetic.native(offset: offset, clearance: clearance)
        return CGPoint(x: native.x, y: native.y)
    }

    /// Where the toolkit shows the scroller standing, counted from its first content clear of what it keeps clear.
    var toolkitStanding: Point {
        SafeAreaArithmetic.offset(
            native: Point(x: scroller.contentOffset.x, y: scroller.contentOffset.y), clearance: clearance)
    }

    // MARK: - The user's movement

    func scrollViewDidScroll(_ scroller: UIScrollView) {
        // A scroll moves whatever stands in the scroller, whoever moved it: a frame read under it is said again.
        laidOut?()
        guard let moved = scrollerOffset.toolkitMoved(to: toolkitStanding) else { return }
        movement.userMoved(from: moved.from, to: moved.to)
    }

    func scrollViewWillBeginDragging(_ scroller: UIScrollView) {
        scrollerOffset.userTookHold()
        movement.holdBegan()
    }

    func scrollViewDidEndDragging(_ scroller: UIScrollView, willDecelerate decelerate: Bool) {
        movement.holdEnded(rests: !decelerate)
    }

    func scrollViewDidEndDecelerating(_ scroller: UIScrollView) {
        movement.rest()
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

    private func configure(vertical: ScrollIndicatorVisibility, horizontal: ScrollIndicatorVisibility) {
        scroller.isScrollEnabled = orientation != .neither
        scroller.alwaysBounceVertical = orientation == .vertical || orientation == .both
        scroller.alwaysBounceHorizontal = orientation == .horizontal || orientation == .both
        scroller.showsVerticalScrollIndicator = vertical != .never && orientation != .horizontal
        scroller.showsHorizontalScrollIndicator = horizontal != .never && orientation != .vertical
    }

    /// Moves the scroller to `target`, kept within what it reaches, as the program's move.
    private func move(to target: Point) {
        let inset = scroller.contentInset
        let reach = Point(
            x: max(0, scroller.contentSize.width + inset.left + inset.right - scroller.bounds.width),
            y: max(0, scroller.contentSize.height + inset.top + inset.bottom - scroller.bounds.height))
        let kept = ScrollArithmetic.kept(target, reach: reach)
        guard scrollerOffset.programMoves(to: kept) else { return }
        let native = SafeAreaArithmetic.native(offset: kept, clearance: clearance)
        ProgramWrite.perform { scroller.contentOffset = CGPoint(x: native.x, y: native.y) }
    }
}
#endif
