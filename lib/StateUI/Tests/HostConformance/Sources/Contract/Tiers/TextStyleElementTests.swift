// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `TextStyleElementContract` on a host: words stand in the colour and with the spacing between their letters the
/// tree gives them, and those it changes them to - on every element wearing the tier.
@_spi(Host) public enum TextStyleElementTests: ConformanceFamily {
    public static let name = "TextStyleElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(TextStyleElementContract.self).flatMap { element in
            [
                Aspects.holds(TextStyleElementContract.textColor, on: element, .red, then: .blue, with: Words.on(element)),
                Aspects.holds(TextStyleElementContract.characterSpacing, on: element, 0, then: 2, with: Words.on(element)),
            ]
        }
    }
}

/// The words a specimen shows, where it shows words of its own.
enum Words {
    /// What `element`'s specimen wears to show words: its text where it has one, its choices where it chooses.
    static func on(_ element: String) -> [any Worn] {
        switch element {
        case "Picker": [Write(PickerContract.options, ["Some words"]), Write(PickerContract.selectedIndex, 0)]
        case "DatePicker", "TimePicker": []
        default: [Write(TextElementContract.text, "Some words")]
        }
    }
}
