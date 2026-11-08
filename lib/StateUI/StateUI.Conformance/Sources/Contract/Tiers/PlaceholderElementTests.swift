// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PlaceholderElementContract` on a host: an element holding nothing shows the words the tree gives it, and the words
/// the tree changes them to - a field while it is empty, a picker while nothing is chosen.
@_spi(Host) public enum PlaceholderElementTests: ConformanceFamily {
    public static let name = "PlaceholderElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Picker.theUsersChoiceStandsWhileTheTreeChangesItsTitle", proves: [
                Covered(PlaceholderElementContract.placeholder, on: PickerContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let named = State(wrappedValue: false)
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
                            .placeholder(named.wrappedValue ? "Size" : "Pick").id("picker")
                        Button("Name").onClicked { named.wrappedValue = true }.id("change")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.choose(2), on: picker)
                try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 2 }
                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(PlaceholderElementContract.placeholder, on: picker) == "Size" }
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 2, "the user's choice, not argued with")
            },
            Aspects.holds(PlaceholderElementContract.placeholder, on: "Picker", "Size", then: "Color",
                          with: [Write(PickerContract.options, ["S", "M"])]),
        ] + TextInputTests.written.proving(PlaceholderElementContract.self)
    }
}
