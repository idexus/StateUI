// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where an element stands, said to the tree that reads it, the same on every host.
/// Design: docs/design/host/runtime.md#where-a-view-stands
extension MountedElement {
    /// Whether the tree reads where this element itself stands: a state its frame drives, or a handler of its
    /// changes.
    public var readsOwnFrame: Bool {
        driven[.frame] != nil || events[.frameChanged] != nil
    }

    /// Says where the element stands - `numbers`, a frame report's eight - where that changed since it last said:
    /// its place in its parent onto the state its frame drives, and the whole report to its handler.
    public func reportFrame(_ numbers: [Double], in runtime: HostRuntime) {
        guard readsOwnFrame, numbers != reportedFrame else { return }
        reportedFrame = numbers
        if let binding = driven[.frame] {
            runtime.report(.lanes(Array(numbers.prefix(4))), through: binding)
        }
        if let handler = handler(.frameChanged) {
            runtime.dispatch(handler, payload: [.numbers(numbers)])
        }
    }

    /// A frame report's eight numbers for a view standing at `place` in its parent, its top left corner at
    /// `corner` in its window, and the window's content - clear of its chrome - beginning at `content`: the place,
    /// the corner in the window, and the corner from the content's.
    public static func frameNumbers(place: Rect, corner: Point, content: Point) -> [Double] {
        [place.x, place.y, place.width, place.height, corner.x, corner.y, corner.x - content.x, corner.y - content.y]
    }
}
