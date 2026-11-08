// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SliderContract` on a host: its value kept inside its range, the user's move heard once and landing on the state,
/// the program's traveling there heard by nobody.
@_spi(Host) public enum SliderTests: ConformanceFamily {
    public static let name = "Slider"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Slider"),
        ]
    }
}
