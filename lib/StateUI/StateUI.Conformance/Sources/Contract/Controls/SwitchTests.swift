// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SwitchContract` on a host: the user's turn is heard once and lands on the state; the program's is shown and heard
/// by nobody.
@_spi(Host) public enum SwitchTests: ConformanceFamily {
    public static let name = "Switch"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Switch"),
        ]
    }
}
