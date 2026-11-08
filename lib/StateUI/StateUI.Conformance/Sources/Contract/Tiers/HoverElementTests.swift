// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `HoverElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum HoverElementTests: ConformanceFamily {
    public static let name = "HoverElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ViewContract.self).map { element in
            ConformanceCase("\(element).thePointerIsHeardComingAndGoing", proves: [
                Covered(HoverElementContract.pointerEntered, on: element),
                Covered(HoverElementContract.pointerExited, on: element),
            ], needs: [Covered(ViewContract.pointerMoved, on: element)], ViewTests.pointing(element))
        } + BarItemElementCases.items.map(BarItemElementCases.pointed)
    }
}
