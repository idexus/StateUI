// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `StyledElementContract` on a host: an element naming a keyed style takes the values the style gives it - a view,
/// and an item on a bar its host draws itself.
@_spi(Host) public enum StyledElementTests: ConformanceFamily {
    public static let name = "StyledElement"

    public static var cases: [ConformanceCase] {
        (VisualElementTests.written + BarItemElementCases.written).proving(StyledElementContract.self)
    }
}
