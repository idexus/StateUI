// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `HoverElementContract` on a host: the pointer coming over an element and leaving it is heard - a view's, with
/// the moves and presses between, which its case needs too - and a bar's item shows its pointer-over look.
@_spi(Host) public enum HoverElementTests: ConformanceFamily {
    public static let name = "HoverElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ViewContract.self).map { element in
            ConformanceCase("\(element).thePointerIsHeardComingAndGoing", proves: [
                Covered(HoverElementContract.pointerEntered, on: element),
                Covered(HoverElementContract.pointerExited, on: element),
            ], needs: [
                Covered(ViewContract.pointerMoved, on: element), Covered(ViewContract.pointerPressed, on: element),
                Covered(ViewContract.pointerReleased, on: element),
            ], ViewTests.pointing(element))
        } + BarItemElementCases.items.map(BarItemElementCases.pointed)
    }
}
