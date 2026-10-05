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

    /// Where the document stands, as last told or heard.
    private var offset = Point(x: 0, y: 0)

    /// The offset the tree wrote last, whose own scroll event the element is still to raise.
    private var written: Point?

    init() {
        super.init(arrangement: .single)
        attribute("class", "stateui-scroller")
        listen("scroll") { [weak self] in self?.scrolled() }
        listen("pointerdown") { [weak self] in self?.movement.holdBegan() }
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
        style("overflow-x", across ? "auto" : "hidden")
        style("overflow-y", down ? "auto" : "hidden")
        // Its own ways it keeps to itself; across them the user's scrolling goes on to the scroller around it.
        style("overscroll-behavior-x", across ? "contain" : "auto")
        style("overscroll-behavior-y", down ? "contain" : "auto")
        // At least its content and at least the view: a track grows to its maximum only into room left over.
        style("grid-template-columns", across ? "minmax(max-content, 1fr)" : "minmax(0, 1fr)")
        style("grid-template-rows", down ? "minmax(max-content, 1fr)" : "minmax(0, 1fr)")
        attribute("data-bars", bars == .never ? "never" : nil)
        if let offset, offset != self.offset {
            self.offset = offset
            written = offset
            WebRelay.scroll(node, to: offset)
        }
    }

    /// The element scrolled: the user's movement, unless it is the offset the tree just wrote.
    private func scrolled() {
        let now = WebRelay.scroll(of: node)
        if let written, abs(written.x - now.x) < 1, abs(written.y - now.y) < 1 {
            self.written = nil
            offset = now
            return
        }
        written = nil
        let old = offset
        offset = now
        movement.userMoved(from: old, to: now)
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
