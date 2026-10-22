// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a scroller keeps clear on each edge of its room, in its toolkit's terms: the depth of the bars it reaches
/// under there.
@_spi(Host) public struct Clearance: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        (self.top, self.left, self.bottom, self.right) = (top, left, bottom, right)
    }

    /// Nothing kept clear.
    public static let none = Clearance(top: 0, left: 0, bottom: 0, right: 0)

    /// What a bar standing beside a page at its top takes of what stands over the room - the top, under which it
    /// reaches, its own content clear of it and of the sides - and what it leaves the page below it.
    public var underABarAtTheTop: (bar: Clearance, page: Clearance) {
        (Clearance(top: top, left: left, bottom: 0, right: right), Clearance(top: 0, left: left, bottom: bottom, right: right))
    }

    /// What a bar standing beside a page at its bottom - a row of tabs - takes, and what it leaves the page above it.
    public var overABarAtTheBottom: (bar: Clearance, page: Clearance) {
        (Clearance(top: 0, left: left, bottom: bottom, right: right), Clearance(top: top, left: left, bottom: 0, right: right))
    }
}

/// Where a page's content stands against the safe area of the room it stands in - a window, a sheet, a popover - the
/// same on every host: clear of what stands over the room - the platform's bars, a notch, the keyboard, a popover's
/// arrow, the arrangement's own bars - but on an edge where its layout lets it under them - edge to edge, or clear of
/// the keyboard alone - out to the room's edge.
/// Design: docs/design/host/layout.md#the-safe-area
@_spi(Host) public enum SafeAreaArithmetic {
    /// The room a page's content stands in: `safe` - the room clear of what stands over it - reaching out to `whole`
    /// on each edge `edges` lets the content under the bars; `safe` where the content says nothing. The start and
    /// the end are the content's `direction`'s: right to left, the start is the right edge.
    public static func room(safe: Rect, whole: Rect, edges: SafeAreaEdges?, direction: LayoutDirection) -> Rect {
        let under = under(edges, direction: direction)
        let minX = under.left ? whole.x : safe.x
        let minY = under.top ? whole.y : safe.y
        let maxX = under.right ? whole.x + whole.width : safe.x + safe.width
        let maxY = under.bottom ? whole.y + whole.height : safe.y + safe.height
        return Rect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    /// On which edges content standing so runs under what stands over its room: the start and the end are its
    /// `direction`'s; none where it says nothing.
    public static func under(
        _ edges: SafeAreaEdges?, direction: LayoutDirection
    ) -> (top: Bool, left: Bool, bottom: Bool, right: Bool) {
        guard let edges else { return (false, false, false, false) }
        let (start, top, end, bottom) = sides(edges)
        let (left, right) = direction == .rightToLeft ? (end, start) : (start, end)
        return (underTheBars(top), underTheBars(left), underTheBars(bottom), underTheBars(right))
    }

    /// What a scroller filling a page's `room` keeps clear on each edge: where the room reaches past `safe` - under
    /// the bars there - their depth, so its first and last content scroll out from under them; nothing on an edge the
    /// room stands clear of them.
    public static func clearance(room: Rect, safe: Rect) -> Clearance {
        Clearance(
            top: max(0, safe.y - room.y), left: max(0, safe.x - room.x),
            bottom: max(0, room.y + room.height - (safe.y + safe.height)),
            right: max(0, room.x + room.width - (safe.x + safe.width)))
    }





    /// Where a scroller keeping `clearance` stands, counted from its first content clear of the bars: its toolkit's
    /// offset `native` with the start's clearance added.
    public static func offset(native: Point, clearance: Clearance) -> Point {
        Point(x: native.x + clearance.left, y: native.y + clearance.top)
    }

    /// The toolkit's offset for a scroller keeping `clearance` to stand at `offset`: the start's clearance taken off.
    public static func native(offset: Point, clearance: Clearance) -> Point {
        Point(x: offset.x - clearance.left, y: offset.y - clearance.top)
    }

    /// Whether content standing so on an edge runs under the bars and the notch there.
    public static func underTheBars(_ area: SafeArea) -> Bool {
        area == .none || area == .keyboard
    }

    private static func sides(_ edges: SafeAreaEdges) -> (SafeArea, SafeArea, SafeArea, SafeArea) {
        switch edges {
        case .uniform(let area): (area, area, area, area)
        case .edges(let start, let top, let end, let bottom): (start, top, end, bottom)
        }
    }
}

extension MountedElement {
    /// Which edges of the window's safe area this layout stands clear of, as the tree says; nil where it says nothing.
    public var avoidsSafeArea: SafeAreaEdges? {
        value(.avoidsSafeArea).flatMap(SafeAreaEdges.init(propValue:))
    }

    /// The edges a room's content lets it under the bars on - a page's, a popover's: its own content's, which is the
    /// room's one child.
    public var contentSafeArea: SafeAreaEdges? {
        isRoom ? arrangedChildren.first?.avoidsSafeArea : avoidsSafeArea
    }

    /// The scroller a room's content is, or the one it holds alone, layout in layout; nil for none.
    public var pageScroller: MountedElement? {
        var held = isRoom ? arrangedChildren.first : self
        while let element = held {
            if element.type == .scrollView { return element }
            guard element.arrangedChildren.count == 1 else { return nil }
            held = element.arrangedChildren.first
        }
        return nil
    }
}

extension MountedElement {
    /// Whether this element is a room content stands in against a safe area: a page - a window's, a sheet's - or a
    /// popover.
    fileprivate var isRoom: Bool { type == .page || type == .popover }
}
