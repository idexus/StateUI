// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FontElementContract` on a host: words stand in the family, size and weight or slant the tree gives them, scaling
/// with the user's text size as it says, and change as the tree changes them - on every element wearing the tier.
@_spi(Host) public enum FontElementTests: ConformanceFamily {
    public static let name = "FontElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(FontElementContract.self).flatMap { element in
            [
                Aspects.holds(FontElementContract.fontSize, on: element, 14, then: 20, with: Words.on(element)),
                Aspects.holds(FontElementContract.fontAttributes, on: element, .none, then: [.bold, .italic],
                              with: Words.on(element)),
                Aspects.holds(FontElementContract.fontFamily, on: element, "Arial", then: "Courier New", with: Words.on(element)),
                Aspects.holds(FontElementContract.fontAutoScalingEnabled, on: element, true, then: false,
                              with: Words.on(element)),
            ]
        }
    }
}
