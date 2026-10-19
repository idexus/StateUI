// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ScrollView: the browser's own scrolling over one document, never smaller than the view along the ways it
/// scrolls and as wide or tall as the view across them; what the user does with it reported on the display's
/// frames, and an offset the tree writes taken without coming back as the user's.
/// Design: docs/design/platforms/web/layout.md#scrolling
@MainActor
final class WebScrollView: WebLayoutView, FramedScroller {
    /// The user moved the document from one offset to another.
    var onOffsetChanged: (Point, Point) -> Void = { _, _ in }

    /// A movement of the user's came to rest.
    var onScrollStopped: () -> Void = {}

    /// The movement under way, and what it says on the display's frames.
    let movement = ScrollMovement()

    /// Where the document stands as the host knows it, the program's move on its way, and the offset the tree
    /// writes (`ScrollerOffset`).
    private var scrollerOffset = ScrollerOffset()

    init() {
        super.init(arrangement: .single)
        attribute("class", "stateui-scroller")
        listen("scroll") { [weak self] in self?.scrolled() }
        followSize { [weak self] in self?.laidOut() }
        listen("pointerdown") { [weak self] in
            self?.scrollerOffset.userTookHold()
            self?.movement.holdBegan()
        }
        listen("pointerup") { [weak self] in self?.movement.holdEnded(rests: false) }
        listen("pointercancel") { [weak self] in self?.movement.holdEnded(rests: false) }
        apply(orientation: .vertical, bars: .automatic, offset: nil)
    }

    /// The ways the document scrolls, whether its bars show, and an offset the tree writes - down, with its bars, as
    /// it is made, before the tree says.
    func apply(orientation: ScrollOrientation, bars: ScrollIndicatorVisibility, offset: Point?) {
        let across = orientation != .vertical
        let down = orientation != .horizontal
        scrolls = (across, down)
        // Bars always shown stand whether or not there is anything to scroll to.
        let scrolls = bars == .visible ? "scroll" : "auto"
        style("overflow-x", across ? scrolls : "hidden")
        style("overflow-y", down ? scrolls : "hidden")
        // Its own ways it keeps to itself; across them the user's scrolling goes on to the scroller around it.
        style("overscroll-behavior-x", across ? "contain" : "auto")
        style("overscroll-behavior-y", down ? "contain" : "auto")
        // At least its content and at least the view: a track grows to its maximum only into room left over.
        style("grid-template-columns", across ? "minmax(max-content, 1fr)" : "minmax(0, 1fr)")
        style("grid-template-rows", down ? "minmax(max-content, 1fr)" : "minmax(0, 1fr)")
        attribute("data-bars", bars == .never ? "never" : nil)
        if let target = scrollerOffset.written(offset, orientation: orientation) {
            move(to: target)
        }
    }

    /// The browser laid the scroller out: the offset written before, where one waits, is moved to now.
    private func laidOut() {
        guard WebRelay.isLaidOut(node), let target = scrollerOffset.laidOutNow() else { return }
        move(to: target)
    }

    /// Moves the scroller to `target`. The browser stops it at the document's end: where it stopped is read at
    /// once, and the scroll event it raises later says that.
    /// Design: docs/design/host/layout.md#where-a-scroller-stands
    private func move(to target: Point) {
        guard scrollerOffset.programMoves(to: target) else { return }
        WebRelay.scroll(node, to: target)
        scrollerOffset.programLanded(at: WebRelay.scroll(of: node))
    }

    /// The element scrolled: the user's movement, unless it is the program's move arriving.
    private func scrolled() {
        guard let moved = scrollerOffset.toolkitMoved(to: WebRelay.scroll(of: node)) else { return }
        movement.userMoved(from: moved.from, to: moved.to)
    }

    var wantsFrames: Bool { movement.wantsFrames }

    func frame(now: Double) {
        for report in movement.frame(now: now) {
            switch report {
            case .moved(let from, let to): onOffsetChanged(from, to)
            case .rested: onScrollStopped()
            }
        }
    }
}
