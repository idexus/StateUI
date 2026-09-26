// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `BarElementContract` on a host: an arrangement's bar stands on the colour the tree gives it, and the colour the
/// tree changes it to - on every element wearing the tier.
@_spi(Host) public enum BarElementTests: ConformanceFamily {
    public static let name = "BarElement"

    public static var cases: [ConformanceCase] {
        Aspects.holdsOnEveryWearer(BarElementContract.barBackgroundColor, .steelBlue, then: .firebrick)
    }
}
