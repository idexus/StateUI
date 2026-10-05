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
        host.runtime.frames.follow(self, order: view.serial, reads: reads)
        if reads, !observesSize {
            observesSize = true
            WebRelay.observeSize(view.node, WebRelay.listener { [weak host] in host?.runtime.frames.laidOut() })
        }
    }

    /// Says nothing while the browser lays the view out nowhere - on a covered page, a tab not chosen - so the frame
    /// it said last stands.
    func reportFrame() {
        guard let view, let host, WebRelay.isLaidOut(view.node) else { return }
        let box = WebRelay.box(of: view.node)
        let parent = layoutParent?.view.map { WebRelay.box(of: $0.node) } ?? box
        let content = host.contentBox
        let place = Rect(x: box.x - parent.x, y: box.y - parent.y, width: box.width, height: box.height)
        let numbers = MountedElement.frameNumbers(
            place: place, corner: Point(x: box.x, y: box.y), content: Point(x: content.x, y: content.y))
        element.reportFrame(numbers, in: host.runtime)
    }

    /// The element whose layout places this one: the nearest above it with a view.
    var layoutParent: WebElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.layoutParent
    }
}
