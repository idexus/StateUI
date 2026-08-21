import StateUI

/// MAUI: SwipeView.
struct SwipeViewSample: SampleContent {
    @State private var rows = ["Alpha", "Beta", "Gamma"]
    @State private var starred: Set<String> = []
    @State private var lastAct = "Swipe a row"
    @State private var travel = "not swiping"

    static let id = "swipeView"
    static let title = "SwipeView"
    static let summary = "Actions hidden behind a row, revealed by a swipe - or run by the swipe itself."

    static let code = """
        @State private var rows = ["Alpha", "Beta", "Gamma"]
        @State private var starred: Set<String> = []

        VStack {
            ForEach(rows) { row in
                SwipeView {
                    Border {
                        Label(starred.contains(row) ? "★ \\(row)" : row)
                            .padding(14, 12)
                    }
                    .stroke(Palette.outline)
                    .strokeShape(.roundRectangle(8))
                }
                // Revealed by swiping RIGHT: they come from the left edge.
                .leftItems {
                    SwipeItem(starred.contains(row) ? "Unstar" : "Star")
                        .backgroundColor(.gold)
                        .onInvoked {
                            if starred.contains(row) {
                                starred.remove(row)
                            } else {
                                starred.insert(row)
                            }
                        }
                }
                // A full swipe runs the first item with no tap at all.
                .rightItems(mode: .execute) {
                    SwipeItem("Delete")
                        .backgroundColor(.firebrick)
                        .isDestructive(true)
                        .onInvoked {
                            rows.removeAll { $0 == row }
                            starred.remove(row)
                        }
                }
                // The swipe ITSELF, where onInvoked is one ITEM being chosen -
                // reported while the finger is still moving.
                .onSwipeStarted { _ in travel = "swiping" }
                .onSwipeChanging { change in
                    travel = "\\(Int(change.offset)) across"
                }
                .onSwipeEnded { end in
                    travel = end.isOpen ? "left open" : "sprang back"
                }
                .id(row)
            }
        }
        """

    var content: Element {
        VStack {
            ForEach(rows) { row in
                SwipeView {
                    Border {
                        HStack {
                            Label(starred.contains(row) ? "★ \(row)" : row)
                                .fontSize(15)
                                .verticalOptions(.center)

                            Label("swipe either way")
                                .fontSize(12)
                                .textColor(Palette.subtle)
                                .horizontalOptions(.end)
                                .verticalOptions(.center)
                        }
                        .spacing(12)
                        .padding(14, 12)
                    }
                    .stroke(Palette.outline)
                    .strokeThickness(1)
                    .strokeShape(.roundRectangle(8))
                }
                // Revealed by swiping RIGHT, which is what MAUI calls the left
                // items: they come from the left-hand edge.
                .leftItems {
                    SwipeItem(starred.contains(row) ? "Unstar" : "Star")
                        .backgroundColor(.gold)
                        .onInvoked {
                            if starred.contains(row) {
                                starred.remove(row)
                            } else {
                                starred.insert(row)
                            }

                            lastAct = "Starred \(row)"
                        }
                }
                // A full swipe runs the first item with no tap at all, which is
                // what .execute is for.
                .rightItems(mode: .execute) {
                    SwipeItem("Delete")
                        .backgroundColor(.firebrick)
                        .isDestructive(true)
                        .onInvoked {
                            rows.removeAll { $0 == row }
                            starred.remove(row)
                            lastAct = "Deleted \(row)"
                        }
                }
                // The swipe ITSELF, where onInvoked is one ITEM being
                // chosen - reported while the finger is still moving.
                .onSwipeStarted { _ in travel = "swiping" }
                .onSwipeChanging { change in
                    travel = "\(Int(change.offset)) across"
                }
                .onSwipeEnded { end in
                    travel = end.isOpen ? "left open" : "sprang back"
                }
                .id(row)
            }

            Label(rows.isEmpty ? "Every row deleted" : lastAct)
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            Label(travel)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            Button("Put them back")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .isEnabled(rows.count < 3)
                .onClicked {
                    rows = ["Alpha", "Beta", "Gamma"]
                    lastAct = "Swipe a row"
                }

            Label("The three swipe reports are about the SWIPE - it began, it has moved "
                + "this far, it ended open or sprang back - where an item's `onInvoked` is "
                + "about one item being chosen. A row that has to answer mid-drag listens "
                + "to the first three.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The items are NOT views: a SwipeItem is a MenuItem in MAUI - a caption, "
                + "a picture, a colour and something to run - so it takes its own modifiers "
                + "and belongs in one of the four collections and nowhere else.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS THIS NEEDS A FINGER: MAUI maps a SwipeView onto WinUI's "
                + "SwipeControl, which answers touch and pen and not a mouse - measured "
                + "2026-08-13, with the same synthesized drag that moves a Slider and "
                + "reports a pan of 263, 97 leaving these rows exactly where they were. "
                + "A desktop app that must work with a mouse wants a context flyout or a "
                + "button beside the row, not only a swipe.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
