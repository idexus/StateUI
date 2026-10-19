// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a canvas's words stand in their box, the same on every host.
/// Design: docs/design/types/drawing.md#text-in-a-box
extension CanvasArithmetic {
    /// The edge of its box words aligned so stand at: a canvas draws in its own coordinates, so a box's start is its
    /// left and its end its right, whichever way the page reads.
    public static func wordsEdge(_ alignment: TextAlignment) -> TextEdge {
        alignment.edge(in: .leftToRight)
    }

    /// The top of words `height` tall in `box`, aligned down it so: its top, its middle, its bottom.
    public static func wordsTop(height: Double, in box: Rect, down: TextAlignment) -> Double {
        switch down {
        case .start: box.y
        case .center: box.y + (box.height - height) / 2
        case .end: box.y + box.height - height
        }
    }

    /// Where a toolkit writing words from a point anchors them across `box`, standing at `edge`.
    public static func wordsAnchor(_ edge: TextEdge, in box: Rect) -> Double {
        switch edge {
        case .left: box.x
        case .center: box.x + box.width / 2
        case .right: box.x + box.width
        }
    }
}
