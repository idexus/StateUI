// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextAlignmentElementContract` on a host: words stand across and down their room where the tree aligns them, and
/// move as the tree changes it - on every element wearing the tier.
@_spi(Host) public enum TextAlignmentElementTests: ConformanceFamily {
    public static let name = "TextAlignmentElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TextAlignmentElementContract.self).flatMap { element in
            [
                Aspects.holds(TextAlignmentElementContract.horizontalTextAlignment, on: element, .start, then: .center,
                              with: Words.on(element)),
                Aspects.holds(TextAlignmentElementContract.verticalTextAlignment, on: element, .start, then: .end,
                              with: Words.on(element)),
            ]
        }
    }
}
