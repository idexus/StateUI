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
final class UIKitScrollView: UIKitLayoutView, UIScrollViewDelegate {
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

    let scroller = UIScrollView()
    private let document = UIKitScrollDocument()

    /// Holds the content in a stack where the scroller was given more than one child.
    private let wrapper = UIKitStackView(axis: .vertical)
    private var wraps = false

    /// The offset the tree writes, kept for the first layout where it comes before it.
    private var writtenOffset = WrittenScrollOffset()

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

        if let target = writtenOffset.written(offset, standing: self.offset, orientation: orientation) {
            move(to: target)
        }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        document.contentSize(width: width)
    }

    /// Stands UIKit's scroll view over the whole of the room and the document in it, then an offset the tree wrote
    /// before there was one.
    override func arrange(in bounds: Rect) {
        scroller.frame = CGRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        let size = document.documentSize(in: LayoutSize(width: bounds.width, height: bounds.height))
        let documentSize = CGSize(width: size.width, height: size.height)
        if document.frame.size != documentSize { document.frame = CGRect(origin: .zero, size: documentSize) }
        if scroller.contentSize != documentSize { scroller.contentSize = documentSize }
        if let target = writtenOffset.laidOutNow() { move(to: target) }
    }

    /// Keeps `right` and `bottom` points clear at the content's end - the strip of the bars a page's scroller reaches
    /// under there - so the last content scrolls out from under it; the start, and the offsets, stay as they are.
    /// Design: docs/design/host/layout.md#the-safe-area
    func keepEndClear(right: Double, bottom: Double) {
        let inset = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: right)
        guard scroller.contentInset != inset else { return }
        scroller.contentInset = inset
        scroller.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
        scroller.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: right)
    }

    // MARK: - The user's movement

    func scrollViewDidScroll(_ scroller: UIScrollView) {
        // A scroll moves whatever stands in the scroller, whoever moved it: a frame read under it is said again.
        laidOut?()
        let standing = Point(x: scroller.contentOffset.x, y: scroller.contentOffset.y)
        guard !ProgramWrite.isWriting, standing != offset else { return }
        let previous = offset
        offset = standing
        movement.userMoved(from: previous, to: standing)
    }

    func scrollViewWillBeginDragging(_ scroller: UIScrollView) {
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
            x: max(0, scroller.contentSize.width + inset.right - scroller.bounds.width),
            y: max(0, scroller.contentSize.height + inset.bottom - scroller.bounds.height))
        let kept = ScrollArithmetic.kept(target, reach: reach)
        offset = kept
        let standing = Point(x: scroller.contentOffset.x, y: scroller.contentOffset.y)
        guard ScrollArithmetic.differs(kept, standing) else { return }
        ProgramWrite.perform { scroller.contentOffset = CGPoint(x: kept.x, y: kept.y) }
    }
}
#endif
