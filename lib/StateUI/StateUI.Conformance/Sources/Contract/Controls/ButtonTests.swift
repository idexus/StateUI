// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ButtonContract` on a host: each click heard once, a press heard as it goes down and as it is let go, the
/// button's icon, where it stands, how far from the words, and how the words break, the keyboard's shortcut
/// pressing it, its role - drawn, and its key pressing it - and a style that leaves it taking its look along.
@_spi(Host) public enum ButtonTests: ConformanceFamily {
    public static let name = "Button"

    public static var cases: [ConformanceCase] { written.proving(ButtonContract.self) }

    /// Every case written for the element: its own members, and its tiers' a tier's family takes up.
    @MainActor static var written: [ConformanceCase] {
        [
            Aspects.standsAlone("Button"),
            Aspects.holds(ButtonContract.iconPosition, on: "Button", .start, then: .top, with: [
                Write(TextElementContract.text, "Go"), Write(IconElementContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(ButtonContract.iconSpacing, on: "Button", 4, then: 12, with: [
                Write(TextElementContract.text, "Go"), Write(IconElementContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(ButtonContract.role, on: "Button", .primary, then: .destructive,
                          with: [Write(TextElementContract.text, "Go")]),
            ConformanceCase("aRolesKeyPressesTheButtonUnlessItStatesOne", proves: [
                Covered(ButtonContract.role), Covered(ShortcutElementContract.keyboardShortcut, on: ButtonContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self), Covered(FocusElementContract.focus, on: "TextField")]) { s in
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
            ConformanceCase("aStyleThatLeavesTakesItsLookWithIt", proves: [
                Covered(ButtonContract.self),
            ], needs: [Covered(StyledElementContract.style, on: "Button")]) { s in
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
