// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `LeadingContentContract` on a host: the view a title bar holds before its title stands there, and takes the user's
/// hand.
@_spi(Host) public enum LeadingContentTests: ConformanceFamily {
    public static let name = "LeadingContent"

    public static var cases: [ConformanceCase] {
        [TitleBarSlots.stands(LeadingContentContract.self) { bar, button in bar.leadingContent { button } }]
    }
}
