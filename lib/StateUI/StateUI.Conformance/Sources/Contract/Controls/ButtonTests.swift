// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ButtonContract` on a host: each click heard once, a press heard as it goes down and as it is let go, the
/// button's icon, where it stands, how far from the words, and how the words break, the keyboard's shortcut
/// pressing it, its role - drawn, and its key pressing it - and a style that leaves it taking its look along.
@_spi(Host) public enum ButtonTests: ConformanceFamily {
    public static let name = "Button"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Button"),
            ConformanceCase("eachClickIsHeardOnceAndRendersWhatItsHandlerChanged", proves: [
                Covered(ButtonContract.clicked),
            ], needs: [Covered(TextualElementContract.text, on: TextContract.self)]) { s in
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
            Aspects.holds(ButtonContract.iconPosition, on: "Button", .start, then: .top, with: [
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
            ], needs: [Covered(ButtonContract.clicked), Covered(FocusElementContract.focus, on: "TextField")]) { s in
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
            ConformanceCase("aHeldButtonsClickIsItsOwnItsMenuApart", proves: [
                Covered(ButtonContract.menuKind),
            ], needs: [Covered(ButtonContract.clicked), Covered(ActionElementContract.clicked, on: "MenuItem")]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Save")
                            .onClicked { heard.values.append("save") }
                            .menu(.held) { MenuItem("Save as").onClicked { heard.values.append("save as") }.id("saveAs") }
                            .id("save")
                    }
                }
                let save = try s.element("save")
                try s.perform(.activate, on: save)
                s.settle { heard.values == ["save"] }
                s.expect(heard.values, ["save"], "a click is the button's own action")
                s.expect(try s.buttonMenu(of: save), "Save as", "and its menu, held, stands apart")

                try s.perform(.activate, on: s.element("saveAs"))
                s.settle { heard.values == ["save", "save as"] }
                s.expect(heard.values, ["save", "save as"], "an entry of its menu chosen")
            },
            ConformanceCase("aMenusArrowShowsAsTheTreeSays", proves: [
                Covered(ButtonContract.showsMenuArrow),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let shows = State(wrappedValue: true)
                s.start {
                    VStack {
                        Button("Share").menu { MenuItem("Mail") }.showsMenuArrow(shows.wrappedValue).id("share")
                        Button("Change").onClicked { shows.wrappedValue = false }.id("change")
                    }
                }
                s.expect(try s.held(ButtonContract.showsMenuArrow, on: s.element("share")), true, "the arrow shown")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ButtonContract.showsMenuArrow, on: s.element("share")) == false }
                s.expect(try s.held(ButtonContract.showsMenuArrow, on: s.element("share")), false, "and taken away")
                s.expect(try s.buttonMenu(of: s.element("share")), "Mail", "the menu still the click's")
            },
            Aspects.holds(ButtonContract.role, on: "Button", .primary, then: .destructive,
                          with: [Write(TextualElementContract.text, "Go")]),
            ConformanceCase("aRolesKeyPressesTheButtonUnlessItStatesOne", proves: [
                Covered(ButtonContract.role), Covered(ButtonContract.keyboardShortcut),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Cancel").role(.cancel).onClicked { heard.values.append("cancel") }.id("cancel")
                        Button("Save").role(.primary).onClicked { heard.values.append("save") }.id("save")
                        Button("Send").role(.primary).keyboardShortcut("e").onClicked { heard.values.append("send") }
                            .id("send")
                    }
                }

                try s.perform(.pressKeys(KeyboardShortcut(.return, modifiers: [])), on: s.element("save"))
                s.settle { heard.values == ["save"] }
                s.expect(heard.values, ["save"], "Return presses the main action")

                try s.perform(.pressKeys(KeyboardShortcut(.escape, modifiers: [])), on: s.element("cancel"))
                s.settle { heard.values == ["save", "cancel"] }
                s.expect(heard.values, ["save", "cancel"], "Escape presses the way out")

                try s.perform(.pressKeys(KeyboardShortcut("e")), on: s.element("send"))
                s.settle { heard.values == ["save", "cancel", "send"] }
                s.expect(heard.values, ["save", "cancel", "send"], "a shortcut stated takes the place of the role's key")
            },
            ConformanceCase("returnIsTheFieldsWhileItIsTypedInto", proves: [
                Covered(ButtonContract.role),
            ], needs: [Covered(ButtonContract.clicked), Covered(FocusElementContract.focus, on: "TextField")]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        TextField("").id("field")
                        Button("Save").role(.primary).onClicked { heard.values.append("save") }.id("save")
                    }
                }
                let field = try s.element("field")

                try s.perform(.focus, on: field)
                try s.settle { try s.focused(field) }
                try s.perform(.pressKeys(KeyboardShortcut(.return, modifiers: [])), on: s.element("save"))
                s.turn()
                s.expect(heard.values, [], "Return ends what was typed, the button stays as it was")
            },
            Aspects.holds(ButtonContract.lineBreak, on: "Button", .wordWrap, then: .tailTruncation,
                          with: [Write(TextualElementContract.text, "Words enough to break across more than one line")]),
            ConformanceCase("aStyleThatLeavesTakesItsLookWithIt", proves: [
                Covered(ButtonContract.self),
            ], needs: [Covered(VisualElementContract.style, on: "Button")]) { s in
                let platform = State(wrappedValue: false)
                s.start { LeavingStyle(platform: platform.projectedValue) }
                let (styled, bare) = (try s.element("styled"), try s.element("bare"))
                try s.settle { try s.shows(.red, on: styled, at: Point(4, 8)) }

                platform.wrappedValue = true
                let sizes = { () throws -> [Double] in
                    let (one, other) = (try s.place(of: styled), try s.place(of: bare))
                    return [one.width - other.width, one.height - other.height]
                }
                try s.settle {
                    try !s.shows(.red, on: styled, at: Point(4, 8)) && sizes().allSatisfy { abs($0) < 0.5 }
                }
                s.expect(try s.shows(.red, on: styled, at: Point(4, 8)), false, "the style's fill gone")
                let apart = try sizes()
                s.expect(apart[0], 0, within: 0.5, "as wide as one that never wore it")
                s.expect(apart[1], 0, within: 0.5, "as tall")
            },
        ]
    }
}

/// A button wearing the sheet's style - a red fill and wide room - until `platform` says its platform's own look,
/// beside one that never wore the style.
private struct LeavingStyle: View {
    @Binding var platform: Bool
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Button("Save").style(platform ? .platform : nil).id("styled")
            Button("Save").style(.platform).id("bare")
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
        .onCreated {
            application.styles = StyleSheet {
                Style<Button>().background(.red).padding(horizontal: 30, vertical: 20)
            }
        }
    }
}
