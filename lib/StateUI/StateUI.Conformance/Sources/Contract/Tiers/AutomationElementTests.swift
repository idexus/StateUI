// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `AutomationElementContract` on a host: the name automation finds an element by is the one the tree gives it, and
/// the one the tree changes it to - on every element wearing the tier.
@_spi(Host) public enum AutomationElementTests: ConformanceFamily {
    public static let name = "AutomationElement"

    public static var cases: [ConformanceCase] {
        Aspects.holdsOnEveryWearer(
            AutomationElementContract.accessibilityIdentifier, "conformance.first", then: "conformance.second")
    }
}
