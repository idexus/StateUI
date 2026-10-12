// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TrackingElementContract` on a host: words stand with the spacing between their letters the tree gives them, and
/// the one it changes it to - on every element wearing the tier.
@_spi(Host) public enum TrackingElementTests: ConformanceFamily {
    public static let name = "TrackingElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TrackingElementContract.self).map { element in
            Aspects.holds(TrackingElementContract.tracking, on: element, 0, then: 2, with: Words.on(element))
        }
    }
}
