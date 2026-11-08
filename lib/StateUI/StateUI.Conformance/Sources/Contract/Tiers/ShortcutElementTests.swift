// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ShortcutElementContract` on a host: the keys an element is given choose it from the keyboard, unless it is out of
/// reach or a field is being typed into; it holds the keys the tree gives it and changes it to, on every element
/// wearing the tier.
@_spi(Host) public enum ShortcutElementTests: ConformanceFamily {
    public static let name = "ShortcutElement"

    public static var cases: [ConformanceCase] {
        [
            Aspects.holds(
                ShortcutElementContract.keyboardShortcut, on: "Button", KeyboardShortcut("s"),
                then: KeyboardShortcut(.return, modifiers: [.primary, .shift])),
            ConformanceCase("Button.aShortcutPressesTheButton", proves: [
                Covered(ShortcutElementContract.keyboardShortcut, on: ButtonContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Save").keyboardShortcut("s").onClicked { heard.values.append("save") }.id("save")
                        Button("Open").keyboardShortcut("o").isEnabled(false).onClicked { heard.values.append("open") }
                            .id("open")
                        Button("One").keyboardShortcut("1", modifiers: []).onClicked { heard.values.append("one") }
                            .id("one")
                    }
                }

                try s.perform(.pressKeys(KeyboardShortcut("s")), on: s.element("save"))
                s.settle { heard.values == ["save"] }
                s.expect(heard.values, ["save"], "the shortcut presses its button")

                try s.perform(.pressKeys(KeyboardShortcut("o")), on: s.element("open"))
                s.expect(heard.values, ["save"], "a disabled button's shortcut presses nothing")

                try s.perform(.pressKeys(KeyboardShortcut("1", modifiers: [])), on: s.element("one"))
                s.settle { heard.values == ["save", "one"] }
                s.expect(heard.values, ["save", "one"], "a key held with nothing is a shortcut too")
            },
            ConformanceCase("Button.aBareShortcutGivesWayToAFieldBeingTypedInto", proves: [
                Covered(ShortcutElementContract.keyboardShortcut, on: ButtonContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self), Covered(FocusElementContract.focus, on: "TextField")]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        TextField("").id("field")
                        Button("One").keyboardShortcut("1", modifiers: []).onClicked { heard.values.append("one") }
                            .id("one")
                    }
                }
                let field = try s.element("field")

                try s.perform(.focus, on: field)
                try s.settle { try s.focused(field) }
                try s.perform(.pressKeys(KeyboardShortcut("1", modifiers: [])), on: s.element("one"))
                s.turn()
                s.expect(heard.values, [], "the key is the field's, the button stays as it was")
            },
        ] + (ButtonTests.written + MenuItemElementCases.written).proving(ShortcutElementContract.self)
    }
}
