// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PropertyContainerContract` on a host: the name automation finds an element by is the one the tree gives it, and
/// the one the tree changes it to - on every element wearing the tier.
@_spi(Host) public enum PropertyContainerTests: ConformanceFamily {
    public static let name = "PropertyContainer"

    public static var cases: [ConformanceCase] {
        Aspects.holdsOnEveryWearer(PropertyContainerContract.accessibilityIdentifier, "conformance.first", then: "conformance.second")
    }
}
