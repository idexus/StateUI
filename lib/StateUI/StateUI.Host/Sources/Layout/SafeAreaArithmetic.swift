// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a page's content stands against the window's safe area, the same on every host that has one: clear of the
/// bars and the notch, but on an edge where its layout lets it under them - edge to edge, or clear of the keyboard
/// alone - out to the window's edge.
/// Design: docs/design/host/layout.md#the-safe-area
@_spi(Host) public enum SafeAreaArithmetic {
    /// The room a page's content stands in: `safe` - the window's room clear of its bars and notch - reaching out to
    /// `whole` on each edge `edges` lets the content under the bars; `safe` where the content says nothing.
    public static func room(safe: Rect, whole: Rect, edges: SafeAreaEdges?) -> Rect {
        guard let edges else { return safe }
        let (left, top, right, bottom) = sides(edges)
        let minX = underTheBars(left) ? whole.x : safe.x
        let minY = underTheBars(top) ? whole.y : safe.y
        let maxX = underTheBars(right) ? whole.x + whole.width : safe.x + safe.width
        let maxY = underTheBars(bottom) ? whole.y + whole.height : safe.y + safe.height
        return Rect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    /// What a scroller filling a page's `room` keeps clear at its end, as its bars and notch take it: where the room
    /// reaches past `safe` at its right or its bottom - under the bars there - the strip's depth, so its last content
    /// scrolls out from under them; nothing where the room stands clear of them.
    public static func endClearance(room: Rect, safe: Rect) -> (right: Double, bottom: Double) {
        (max(0, room.x + room.width - (safe.x + safe.width)), max(0, room.y + room.height - (safe.y + safe.height)))
    }

    /// Whether content standing so on an edge runs under the bars and the notch there.
    public static func underTheBars(_ area: SafeArea) -> Bool {
        area == .none || area == .keyboard
    }

    private static func sides(_ edges: SafeAreaEdges) -> (SafeArea, SafeArea, SafeArea, SafeArea) {
        switch edges {
        case .uniform(let area): (area, area, area, area)
        case .edges(let left, let top, let right, let bottom): (left, top, right, bottom)
        }
    }
}

extension MountedElement {
    /// Which edges of the window's safe area this layout stands clear of, as the tree says; nil where it says nothing.
    public var avoidsSafeArea: SafeAreaEdges? {
        value(.avoidsSafeArea).flatMap(SafeAreaEdges.init(propValue:))
    }

    /// The edges a page's content lets it under the bars on: its own content's, which is the page's one child.
    public var contentSafeArea: SafeAreaEdges? {
        type == .page ? children.first?.avoidsSafeArea : avoidsSafeArea
    }

    /// The scroller a page's content is, or the one it holds alone, layout in layout; nil for none.
    public var pageScroller: MountedElement? {
        var held = type == .page ? children.first : self
        while let element = held {
            if element.type == .scrollView { return element }
            guard element.children.count == 1 else { return nil }
            held = element.children.first
        }
        return nil
    }
}
