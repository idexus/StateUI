// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `CheckBoxContract` on a host: the user's tick is heard once and lands on the state; the program's is shown and
/// heard by nobody.
@_spi(Host) public enum CheckBoxTests: ConformanceFamily {
    public static let name = "CheckBox"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("CheckBox"),
        ]
    }
}
