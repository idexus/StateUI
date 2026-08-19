import StateUI

/// The panel every tab of the demonstration carries: what the tab list is, what
/// the selection puts on the wire, and the buttons that change that list while a
/// tab is showing.
///
/// It is on EVERY tab page rather than on one of them, because what is being
/// watched is which tab the platform leaves showing - so wherever it lands, the
/// same readings are under it.
struct TabsControls: ContentView {
    /// Where the gallery is, and the moves that change the tab list.
    let nav: Navigation

    /// The tab this copy of the panel is on, which is what lets it say whether
    /// the binding and the screen agree.
    let thisTab: DemoTab

    var content: Element {
        VStack {
            SectionTitle("THE TAB BAR, AS SWIFT DESCRIBES IT")

            VStack {
                ForEach(Array(nav.tabs.enumerated()), id: \.offset) { pair in
                    row(index: pair.offset, tab: pair.element)
                }
            }
            .spacing(4)

            Label("currentPage on the wire · \(onTheWire)")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)

            if agrees {
                Label(verdict)
                    .fontSize(12)
                    .textColor(Palette.subtle)
            } else {
                HStack {
                    WarningMark()

                    Label(verdict)
                        .fontSize(12)
                        .fontAttributes(.bold)
                        .textColor(Palette.accent)
                }
                .spacing(6)
            }

            SectionTitle("CHANGE THE LIST WHILE IT IS SHOWING")

            move("Add a tab at the end") { nav.addTab(showing: thisTab) }

            move("Insert a tab before this one") {
                nav.insertTab(before: thisTab, showing: thisTab)
            }

            move("Reverse the tabs") { nav.reverseTabs(showing: thisTab) }

            move("Reset") { nav.resetTabs() }

            Label("last move · \(nav.tabsNote)")
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }

    /// One row of the printed list: its index, its caption, whether it is the
    /// one selected, and a way to close it.
    ///
    /// The last row keeps no close button: a tab bar with nothing in it draws no
    /// page, so there would be nothing left to press.
    private func row(index: Int, tab: DemoTab) -> Element {
        HStack {
            Label("\(index)")
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.subtle)
                .widthRequest(24)

            Label(tab.caption)
                .fontSize(13)
                .textColor(tab == nav.tab ? Palette.accent : Palette.text)
                .widthRequest(90)

            Label(tab == nav.tab ? "◀ selected" : " ")
                .fontSize(12)
                .textColor(Palette.accent)
                .widthRequest(80)

            if nav.tabs.count > 1 {
                Button("close")
                    .fontSize(12)
                    .padding(10, 2)
                    .onClicked { nav.closeTab(tab, showing: thisTab) }
            }
        }
        .spacing(8)
    }

    /// One of the buttons, all of which look the same.
    private func move(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(16, 6)
            .horizontalOptions(.start)
            .onClicked(act)
    }

    /// What `TabbedPage.selection` writes for this selection - the same line the
    /// library runs, repeated here so that the number is on screen.
    ///
    /// A property is sent only when its VALUE changed, so a move that leaves
    /// this number alone sends nothing at all and the tab bar is rebuilt
    /// underneath a selection nobody restated. That is the case `Reverse the
    /// tabs` makes, from the middle of three.
    private var onTheWire: String {
        guard let index = nav.tabs.firstIndex(of: nav.tab) else {
            return "nothing - the selection names no tab"
        }

        return "\(index)"
    }

    /// Whether the binding and the tab actually on screen are the same tab.
    private var agrees: Bool {
        nav.tab == thisTab
    }

    /// What that comparison says, in words.
    private var verdict: String {
        agrees
            ? "The binding says \(thisTab.caption), and \(thisTab.caption) is what you are looking at."
            : "THE BINDING SAYS \(nav.tab.caption) - YOU ARE LOOKING AT \(thisTab.caption)."
    }
}
