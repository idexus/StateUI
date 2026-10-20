// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextColorElementContract` on a host: words stand in the colour the tree gives them, and the one it changes them
/// to - on every element wearing the tier.
@_spi(Host) public enum TextColorElementTests: ConformanceFamily {
    public static let name = "TextColorElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TextColorElementContract.self).map { element in
            Aspects.holds(TextColorElementContract.textColor, on: element, .red, then: .blue, with: Words.on(element))
        }
    }
}

/// The words a specimen shows, where it shows words of its own.
@MainActor
enum Words {
    /// What `element`'s specimen wears to show words: its text where it has one, its choices where it chooses;
    /// nothing where it shows no words of its own - a layout, a date.
    static func on(_ element: String) -> [any Worn] {
        if element == "Picker" {
            return [Write(PickerContract.options, ["Some words"]), Write(PickerContract.selectedIndex, 0)]
        }
        guard Specimens.wearing(TextualElementContract.self).contains(element) else { return [] }
        return [Write(TextualElementContract.text, "Some words")]
    }
}
