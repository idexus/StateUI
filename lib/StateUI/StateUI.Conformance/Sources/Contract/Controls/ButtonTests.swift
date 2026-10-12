// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ButtonContract` on a host: each click heard once, a press heard as it goes down and as it is let go, the
/// button's icon, where it stands, how far from the words, and how the words break, and the keyboard's shortcut
/// pressing it.
@_spi(Host) public enum ButtonTests: ConformanceFamily {
    public static let name = "Button"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Button"),
            ConformanceCase("eachClickIsHeardOnceAndRendersWhatItsHandlerChanged", proves: [
                Covered(ButtonContract.clicked),
                Covered(TextualElementContract.text, on: TextContract.self),
            ]) { s in
                let count = State(wrappedValue: 0)
                let heard = Received<Int>()
                s.start {
                    VStack {
                        Text("count \(count.wrappedValue)").id("label")
                        Button("Add").onClicked {
                            count.wrappedValue += 1
                            heard.values.append(count.wrappedValue)
                        }.id("button")
                    }
                }
                let button = try s.element("button")

                try s.perform(.activate, on: button)
                try s.settle { try s.held(TextualElementContract.text, on: s.element("label")) == "count 1" }
                try s.perform(.activate, on: button)
                try s.settle { try s.held(TextualElementContract.text, on: s.element("label")) == "count 2" }

                s.expect(heard.values, [1, 2], "each click heard once")
                s.expect(try s.held(TextualElementContract.text, on: s.element("label")), "count 2")
            },
            ConformanceCase("aPressIsHeardAsItGoesDownAndAsItIsLetGo", proves: [
                Covered(ButtonContract.pressed), Covered(ButtonContract.released),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Hold")
                            .onPressed { heard.values.append("pressed") }
                            .onReleased { heard.values.append("released") }
                            .width(120).height(40).id("button")
                    }
                    .horizontalAlignment(.start)
                }
                let button = try s.element("button")

                try s.perform(.pressDown(at: Point(60, 20)), on: button)
                s.settle { heard.values == ["pressed"] }
                s.expect(heard.values, ["pressed"], "heard as it goes down, before it is let go")

                try s.perform(.lift(at: Point(60, 20)), on: button)
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["pressed", "released"])
            },
            Aspects.holds(ButtonContract.icon, on: "Button", "test_dot.png", then: "test_wide.png",
                          with: [Write(TextualElementContract.text, "Go")]),
            Aspects.holds(ButtonContract.iconPosition, on: "Button", .leading, then: .top, with: [
                Write(TextualElementContract.text, "Go"), Write(ButtonContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(ButtonContract.iconSpacing, on: "Button", 4, then: 12, with: [
                Write(TextualElementContract.text, "Go"), Write(ButtonContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(
                ButtonContract.keyboardShortcut, on: "Button", KeyboardShortcut("s"),
                then: KeyboardShortcut(.return, modifiers: [.primary, .shift])),
            ConformanceCase("aShortcutPressesTheButton", proves: [
                Covered(ButtonContract.keyboardShortcut),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
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
            ConformanceCase("aBareShortcutGivesWayToAFieldBeingTypedInto", proves: [
                Covered(ButtonContract.keyboardShortcut),
            ], needs: [Covered(ButtonContract.clicked), Covered(VisualElementContract.focus, on: "TextField")]) { s in
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
                s.expect(heard.values, [], "the key is the field's, the button stays as it was")
            },
            Aspects.holds(ButtonContract.lineBreak, on: "Button", .wordWrap, then: .tailTruncation,
                          with: [Write(TextualElementContract.text, "Words enough to break across more than one line")]),
        ]
    }
}
