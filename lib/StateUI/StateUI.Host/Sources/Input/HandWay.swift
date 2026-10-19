// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which way the hand moves a layout: along one axis - a scroll's, a swipe's, a page's - or every way, a pan's.
/// Design: docs/design/host/runtime.md#the-hand-over-a-layout
@_spi(Host) public enum HandWay: Hashable, Sendable {
    /// Across: the hand moving sideways.
    case horizontal

    /// Down: the hand moving up and down.
    case vertical

    /// Every way: a pan, whose first move is the layout's whichever way it goes.
    case everyWay

    /// The way of a hand along `axis`.
    public init(_ axis: LayoutInput.Axis) {
        self = axis == .horizontal ? .horizontal : .vertical
    }
}
