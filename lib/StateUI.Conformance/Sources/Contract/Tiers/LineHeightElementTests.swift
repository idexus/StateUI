// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LineHeightElementContract` on a host: words stand as far apart line from line as the tree says, and as the tree
/// changes it - on every element wearing the tier.
@_spi(Host) public enum LineHeightElementTests: ConformanceFamily {
    public static let name = "LineHeightElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(LineHeightElementContract.self).map { element in
            Aspects.holds(LineHeightElementContract.lineHeight, on: element, 1, then: 1.5, with: Words.on(element))
        }
    }
}
