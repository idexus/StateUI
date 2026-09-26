// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `TrailingContentContract` on a host: the view a title bar holds at its far end stands there, and takes the user's
/// hand.
@_spi(Host) public enum TrailingContentTests: ConformanceFamily {
    public static let name = "TrailingContent"

    public static var cases: [ConformanceCase] {
        [TitleBarSlots.stands(TrailingContentContract.self) { bar, button in bar.trailingContent { button } }]
    }
}
