// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where the element's view stands, said to the tree that reads it on the display's frame after the page moved.
/// Design: docs/design/platforms/web/layout.md#where-a-view-stands
extension WebElement: FrameReporter {
    /// Follows the view while the tree reads where it stands: its size changing moves it, and so does the page.
    func followFrame() {
        guard let view, let host else { return }
        let reads = element.readsOwnFrame
        host.runtime.frames.follow(self, of: element, reads: reads)
        if reads, !observesSize {
            observesSize = true
            view.followSize { [weak host] in host?.runtime.frames.laidOut() }
        }
    }

    /// Says nothing while the browser lays the view out nowhere - on a covered page, a tab not chosen - so the frame
    /// it said last stands; a split view says where its sidebar stands too.
    func reportFrame() {
        guard let view, let host, WebRelay.isLaidOut(view.node) else { return }
        let laid = WebRelay.box(of: view.node)
        let box = view.frame(laidOut: laid) ?? laid
        let content = host.contentBox
        let numbers = MountedElement.frameNumbers(
            place: placeInLayout ?? placeAsDrawn(box), corner: windowCorner ?? Point(x: box.x, y: box.y),
            content: Point(x: content.x, y: content.y))
        element.reportFrame(numbers, in: host.runtime)
        if let split = view as? WebSplitView { element.reportSidebarOverlays(split.overlays, in: host.runtime) }
    }

    /// Where the top left corner of the view's laid-out rectangle stands on the page, no transform in it.
    /// Design: docs/design/host/runtime.md#a-corner-in-the-window
    var windowCorner: Point? {
        element.cornerInWindow(
            toolkit: { ($0.native as? WebElement)?.cornerAsDrawn },
            place: { ($0.native as? WebElement)?.placeInLayout.map { Point(x: $0.x, y: $0.y) } },
            scrolled: { ($0.native as? WebElement)?.view.map { WebRelay.scroll(of: $0.node) } ?? .zero })
    }

    /// Where the view stands in the layout placing it, as that layout laid it out - no transform in it, and its place
    /// in a scroller's content as it scrolls; nil where the page lays out no such place.
    var placeInLayout: Rect? {
        guard let view, let layout = layoutParent?.view,
              let place = WebRelay.places([(layout.node, view.node)]).first ?? nil else { return nil }
        return view.frame(laidOut: place) ?? place
    }

    /// Where the view's box stands in the layout placing it, as the page draws both - `box` its own.
    private func placeAsDrawn(_ box: Rect) -> Rect {
        let layout = layoutParent?.view
        let parent = layout.map { WebRelay.box(of: $0.node) } ?? box
        // A parent that scrolls holds its children in its content: their place there stays as it scrolls.
        let scrolled = layout.map { WebRelay.scroll(of: $0.node) } ?? .zero
        return Rect(
            x: box.x - parent.x + scrolled.x, y: box.y - parent.y + scrolled.y, width: box.width, height: box.height)
    }

    /// Where the view's top left corner stands on the page as the browser draws it, its transforms and its layouts'
    /// in; nil for no view.
    private var cornerAsDrawn: Point? {
        guard let view else { return nil }
        let laid = WebRelay.box(of: view.node)
        let box = view.frame(laidOut: laid) ?? laid
        return Point(x: box.x, y: box.y)
    }

    /// The element whose layout places this one: the nearest above it with a view (`MountedElement.layoutParent`).
    var layoutParent: WebElement? {
        element.layoutParent?.native as? WebElement
    }
}
