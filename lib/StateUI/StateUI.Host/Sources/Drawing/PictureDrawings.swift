// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The drawings of one vector picture a view shows, by their pixels: the one it shows and the one on its way. A
/// view asks for a drawing only for more pixels than either holds, shows what it holds while one is on its way, and
/// takes a drawing that lands only while it is the one on its way - the same on every host.
/// Design: docs/design/host/layout.md#a-picture
@_spi(Host) public struct PictureDrawings: Sendable, Equatable {
    /// The pixels of the drawing shown; nil before one landed.
    public private(set) var shown: LayoutSize?

    /// The pixels of the drawing on its way; nil while none is.
    public private(set) var coming: LayoutSize?

    /// Nothing drawn yet.
    public init() {}

    /// The pixels to draw for `wanted` (`PictureArithmetic.vectorPixels`), now on their way; nil where the drawing
    /// shown, or the one on its way, holds as many either way.
    public mutating func asks(for wanted: LayoutSize) -> LayoutSize? {
        if let held = coming ?? shown, wanted.width <= held.width, wanted.height <= held.height { return nil }
        coming = wanted
        return wanted
    }

    /// A drawing of `pixels` landed: whether it is the one on its way, which is shown from now on.
    public mutating func landed(_ pixels: LayoutSize) -> Bool {
        guard coming == pixels else { return false }
        (shown, coming) = (pixels, nil)
        return true
    }

    /// The drawing of `pixels` on its way was not made: none is on its way, so the next asking draws again.
    public mutating func lost(_ pixels: LayoutSize) {
        if coming == pixels { coming = nil }
    }
}
