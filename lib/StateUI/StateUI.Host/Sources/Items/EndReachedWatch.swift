// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// When a list says the user reached its end: as the last item in view comes within `within` of the last item -
/// once, until the user scrolls away from the end or items come or go.
/// Design: docs/design/host/items.md#the-end-reached
@_spi(Host) public struct EndReachedWatch: Sendable {
    private var armed = true

    /// A watch that has said nothing yet.
    public init() {}

    /// Items came or went: the end is told again as it is reached.
    public mutating func itemsCameOrWent() {
        armed = true
    }

    /// Whether the end is reached now, for a list of `count` items whose last in view stands at `last`.
    public mutating func reached(count: Int, last: Int, within: Int) -> Bool {
        guard count > 0, last >= count - 1 - max(within, 0) else {
            armed = true
            return false
        }
        guard armed else { return false }
        armed = false
        return true
    }
}
