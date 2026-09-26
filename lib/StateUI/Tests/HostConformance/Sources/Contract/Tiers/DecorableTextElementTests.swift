// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `DecorableTextElementContract` on a host: words stand underlined or struck through as the tree says, and as the
/// tree changes it - on every element wearing the tier.
@_spi(Host) public enum DecorableTextElementTests: ConformanceFamily {
    public static let name = "DecorableTextElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(DecorableTextElementContract.self).map { element in
            Aspects.holds(DecorableTextElementContract.textDecorations, on: element, .underline, then: .strikethrough,
                          with: Words.on(element))
        }
    }
}
