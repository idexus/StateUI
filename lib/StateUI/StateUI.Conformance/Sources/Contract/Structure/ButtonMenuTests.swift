// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ButtonMenuContract` on a host: a button holding a menu offers its entries - an entry chosen runs - and follows
/// the states they read; one with a click of its own splits, its click its action and its menu apart.
@_spi(Host) public enum ButtonMenuTests: ConformanceFamily {
    public static let name = "ButtonMenu"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aButtonsMenuOffersItsEntries", proves: [
                Covered(ButtonMenuContract.self),
            ], needs: [Covered(ActionElementContract.clicked, on: "MenuItem")]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Share").menu {
                            MenuItem("Mail").onClicked { heard.values.append("mail") }.id("mail")
                            MenuSeparator()
                            MenuItem("Link").isEnabled(false).id("link")
                        }.id("share")
                    }
                }
                s.expect(try s.buttonMenu(of: s.element("share")), "Mail;-;!Link")

                try s.perform(.activate, on: s.element("mail"))
                s.settle { heard.values == ["mail"] }
                s.expect(heard.values, ["mail"], "the entry chosen runs")
            },
            ConformanceCase("aButtonWithAClickOfItsOwnSplits", proves: [
                Covered(ButtonMenuContract.self),
            ], needs: [Covered(ButtonContract.clicked), Covered(ActionElementContract.clicked, on: "MenuItem")]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Save")
                            .onClicked { heard.values.append("save") }
                            .menu { MenuItem("Save as").onClicked { heard.values.append("save as") }.id("saveAs") }
                            .id("save")
                    }
                }
                let save = try s.element("save")
                try s.perform(.activate, on: save)
                s.settle { heard.values == ["save"] }
                s.expect(heard.values, ["save"], "a click is the button's own action")
                s.expect(try s.buttonMenu(of: save), "Save as", "and its menu stands apart")

                try s.perform(.activate, on: s.element("saveAs"))
                s.settle { heard.values == ["save", "save as"] }
                s.expect(heard.values, ["save", "save as"], "an entry of its menu chosen")
            },
            ConformanceCase("aButtonsMenuFollowsTheStatesItsEntriesRead", proves: [
                Covered(ButtonMenuContract.self),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let shares = State(wrappedValue: ["Mail"])
                s.start {
                    VStack {
                        Button("Share").menu { shares.wrappedValue.map { MenuItem($0).id($0) } }.id("share")
                        Button("More").onClicked { shares.wrappedValue.append("Chat") }.id("more")
                    }
                }
                let share = try s.element("share")
                s.expect(try s.buttonMenu(of: share), "Mail")

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.buttonMenu(of: share) == "Mail;Chat" }
                s.expect(try s.buttonMenu(of: share), "Mail;Chat", "an entry added")
            },
        ]
    }
}
