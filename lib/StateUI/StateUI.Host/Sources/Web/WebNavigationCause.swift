// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a web view's navigation began: the step the program asked for - back, forward, the page again - else what the
/// platform tells, kept to the navigation's end whatever is asked meanwhile.
/// Design: docs/design/host/web.md#why-a-navigation-began
@_spi(Host) public struct WebNavigationCause {
    /// The step the program asked for and no navigation has begun for yet.
    private var asked: WebNavigationType?

    /// Why the navigation under way began.
    public private(set) var current = WebNavigationType.unknown

    /// No step asked, and no navigation under way.
    public init() {}

    /// The program asked the view for `step`: the next navigation to begin is its.
    public mutating func ask(_ step: WebNavigationType) {
        asked = step
    }

    /// A navigation began, which the platform tells as `told`: why it began.
    public mutating func begin(told: WebNavigationType) -> WebNavigationType {
        current = asked ?? told
        asked = nil
        return current
    }
}
