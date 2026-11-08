// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a web view's navigation began: the step the program asked for - back, forward, the page again - else what the
/// platform tells, kept to the navigation's end whatever is asked meanwhile.
/// Design: docs/design/host/web.md#why-a-navigation-began
@_spi(Host) public struct WebNavigationCause {
    /// The step the program asked for and no navigation has begun for yet.
    private var asked: WebNavigationKind?

    /// Why the navigation under way began.
    public private(set) var current = WebNavigationKind.unknown

    /// No step asked, and no navigation under way.
    public init() {}

    /// Records `step` only where the toolkit can take it. A refused step leaves an earlier request intact.
    /// Call this between reading the native capability and invoking a toolkit that may report synchronously.
    @discardableResult
    public mutating func ask(_ step: WebNavigationKind, if possible: Bool) -> Bool {
        guard possible else { return false }
        asked = step
        return true
    }

    /// A navigation began, which the platform tells as `told`: why it began.
    public mutating func begin(told: WebNavigationKind) -> WebNavigationKind {
        current = asked ?? told
        asked = nil
        return current
    }
}
