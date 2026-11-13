// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ButtonMenuElementContract` on a host: a button holding a menu - a button among views, a bar's button on the bar at
/// the top or at the page's foot - held keeps its click its own and its menu apart, and shows the arrow saying its
/// click opens the menu as the tree says; each case made for every element wearing the tier.
@_spi(Host) public enum ButtonMenuElementTests: ConformanceFamily {
    public static let name = "ButtonMenuElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ButtonMenuElementContract.self).flatMap { element in
            [held(element), arrow(element)]
        } + [held(ToolbarButtonContract.nodeType.name, at: .foot)]
    }

    /// A held button's click is its own action, and its menu stands apart.
    @MainActor
    static func held(_ element: String, at place: MenuButtons.BarPlace = .top) -> ConformanceCase {
        ConformanceCase("\(element)\(place.named).aHeldButtonsClickIsItsOwnItsMenuApart", proves: [
            Covered(ButtonMenuElementContract.menuKind, on: element),
        ], needs: [clicking(element), Covered(ClickElementContract.clicked, on: "MenuItem")]) { s in
            let heard = Received<String>()
            s.start {
                MenuButtons.standing(
                    element, "Save", clicked: { heard.values.append("save") }, kind: .held, at: place,
                    entries: { MenuItem("Save as").onClicked { heard.values.append("save as") }.id("saveAs") })
            }
            let save = try s.element("save")
            try s.perform(.activate, on: save)
            s.settle { heard.values == ["save"] }
            s.expect(heard.values, ["save"], "a click is the button's own action")
            s.expect(try s.buttonMenu(of: save), "Save as", "and its menu, held, stands apart")

            try s.perform(.activate, on: s.element("saveAs"))
            s.settle { heard.values == ["save", "save as"] }
            s.expect(heard.values, ["save", "save as"], "an entry of its menu chosen")
        }
    }

    /// The arrow saying a click opens the menu shows as the tree says.
    @MainActor
    static func arrow(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aMenusArrowShowsAsTheTreeSays", proves: [
            Covered(ButtonMenuElementContract.showsMenuArrow, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let shows = State(wrappedValue: true)
            s.start {
                MenuButtons.standing(
                    element, "Share", arrow: shows.wrappedValue, entries: { MenuItem("Mail") },
                    beside: [Button("Change").onClicked { shows.wrappedValue = false }.id("change")])
            }
            s.expect(try s.held(ButtonMenuElementContract.showsMenuArrow, on: s.element("share")), true, "the arrow shown")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(ButtonMenuElementContract.showsMenuArrow, on: s.element("share")) == false }
            s.expect(
                try s.held(ButtonMenuElementContract.showsMenuArrow, on: s.element("share")), false, "and taken away")
            s.expect(try s.buttonMenu(of: s.element("share")), "Mail", "the menu still the click's")
        }
    }

    /// What clicking a button of `element`'s kind is heard as.
    static func clicking(_ element: String) -> Covered {
        element == "ToolbarButton" ? Covered(ClickElementContract.clicked, on: element) : Covered(ClickElementContract.clicked, on: ButtonContract.self)
    }
}

/// A button holding a menu as each element wearing `ButtonMenuElement` stands: a button among views, a bar's button
/// on its page's bar over a stack - at its top or its foot, or behind either's overflow.
enum MenuButtons {
    /// Where a bar's button stands.
    enum BarPlace {
        case top, foot, topOverflow, footOverflow

        /// The words a case's name takes for the place: none on the bar at the top.
        var named: String {
            switch self {
            case .top: ""
            case .foot: ".atTheFoot"
            case .topOverflow: ".inTheOverflow"
            case .footOverflow: ".inTheFootsOverflow"
            }
        }
    }

    /// A button of `element`'s kind saying `text`, known by its words in lower case, clicked as `clicked` says,
    /// holding a menu of `entries` opening as `kind` asks, its arrow as `arrow` says, `beside` views of its page - a
    /// bar's button standing at `place`.
    @MainActor
    static func standing(
        _ element: String, _ text: String, clicked: (@MainActor () -> Void)? = nil, kind: ButtonMenuKind = .automatic,
        arrow: Bool? = nil, at place: BarPlace = .top, @MenuBuilder entries: @escaping @MainActor () -> MenuEntries,
        beside: [any View] = []
    ) -> AnyView {
        let id = text.lowercased()
        if element == "ToolbarButton" {
            var item = ToolbarButton(text).menu(kind, entries).id(id)
            if let arrow { item = item.showsMenuArrow(arrow) }
            if let clicked { item = item.onClicked(clicked) }
            if place == .topOverflow || place == .footOverflow { item = item.placement(at: .overflow) }
            let page = item
            if place == .foot || place == .footOverflow {
                return AnyView(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    VStack { Beside([Text("Page")] + beside) }.toolbar(.bottom) { page }
                } destination: { _ in Text("Pushed") })
            }
            return AnyView(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage(beside: beside) { [page] }
            } destination: { _ in Text("Pushed") })
        }
        var button = Button(text).menu(kind, entries).id(id)
        if let arrow { button = button.showsMenuArrow(arrow) }
        if let clicked { button = button.onClicked(clicked) }
        return AnyView(VStack { Beside([button] + beside) })
    }
}
