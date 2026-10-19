// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The edge words stand at across their room, as a toolkit names it with no direction of its own.
@_spi(Host) public enum TextEdge: Sendable {
    case left, center, right
}

extension TextAlignment {
    /// The edge words aligned so stand at as `direction` reads: a line's start is the left left to right and the
    /// right right to left, its end the other way - the same on every host, a canvas's words included.
    /// Design: docs/design/host/layout.md#words-across-their-room
    @_spi(Host) public func edge(in direction: LayoutDirection) -> TextEdge {
        switch self {
        case .start: direction == .rightToLeft ? .right : .left
        case .center: .center
        case .end: direction == .rightToLeft ? .left : .right
        }
    }
}
