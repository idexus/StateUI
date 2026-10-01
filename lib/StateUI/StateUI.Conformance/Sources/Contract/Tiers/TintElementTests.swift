// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TintElementContract` on a host: a control wears the tint the tree gives it where the platform shows its accent,
/// and the tint the tree changes it to - on every element wearing the tier.
@_spi(Host) public enum TintElementTests: ConformanceFamily {
    public static let name = "TintElement"

    public static var cases: [ConformanceCase] {
        Aspects.holdsOnEveryWearer(TintElementContract.tint, .red, then: .blue)
    }
}
