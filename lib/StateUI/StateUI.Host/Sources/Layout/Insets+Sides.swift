// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// An inset's four sides as a toolkit with no direction of its own names them.
@_spi(Host) public struct InsetSides: Equatable, Sendable {
    /// The space on the left.
    public let left: Double
    /// The space above.
    public let top: Double
    /// The space on the right.
    public let right: Double
    /// The space below.
    public let bottom: Double
}

extension Insets {
    /// The sides as an element laid out in `direction` stands them: the start is the left left to right and the right
    /// right to left, the end the other way - what a toolkit's own control, padded by left and right, is given.
    /// Design: docs/design/host/layout.md#right-to-left
    @_spi(Host) public func sides(in direction: LayoutDirection) -> InsetSides {
        direction == .rightToLeft
            ? InsetSides(left: end, top: top, right: start, bottom: bottom)
            : InsetSides(left: start, top: top, right: end, bottom: bottom)
    }
}
