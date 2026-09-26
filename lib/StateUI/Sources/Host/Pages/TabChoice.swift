// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which tab a tabbed view shows, the same on every host: none chosen until the tree or the user chooses one; a tab
/// the tree asks for anew is chosen; the user's choice stands where it is another tab there is.
/// Design: docs/design/host/pages.md#tabs
@_spi(Host) public struct TabChoice: Equatable, Sendable {
    /// The tab chosen; nil until one is.
    public private(set) var chosen: Int?

    /// No tab chosen yet.
    public init() {}

    /// The tab shown: the chosen one, else the first.
    public var shown: Int {
        chosen ?? 0
    }

    /// The tree asks for `requested`: whether the choice changed.
    public mutating func request(_ requested: Int?) -> Bool {
        guard let requested, requested != chosen else { return false }

        chosen = requested
        return true
    }

    /// The user chooses tab `index` of `count`: the tab shown before, where the choice changed; nil where it did not.
    public mutating func choose(_ index: Int, of count: Int) -> Int? {
        let previous = shown
        guard index != previous, (0..<count).contains(index) else { return nil }

        chosen = index
        return previous
    }
}
