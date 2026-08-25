import StateUI

/// MAUI: SwipeView.
struct SwipeViewSample: SampleContent {
    @State private var rows = ["Alpha", "Beta", "Gamma"]
    @State private var starred: Set<String> = []
    @State private var archived = false
    @State private var lastAct = "Swipe a row"
    @State private var travel = "not swiping"

    static let id = "swipeView"
    static let title = "SwipeView"
    static let summary = "Actions hidden behind a row, revealed by a swipe - or run by the swipe itself."

    // The top and bottom items are revealed by a swipe UP or DOWN, and a
    // scroller around the card would claim that drag before the card heard
    // about it - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var rows = ["Alpha", "Beta", "Gamma"]
        @State private var starred: Set<String> = []
        @State private var archived = false
        @State private var lastAct = "Swipe a row"
        @State private var travel = "not swiping"

        // How far each row has to travel before its items come out. The same
        // items three times, so the difference is in the finger.
        private static let thresholds = ["Alpha": 20.0, "Beta": 80.0, "Gamma": 160.0]

        VStack {
            ForEach(rows) { row in
                let needed = Self.thresholds[row] ?? 20

                return SwipeView {
                    Border {
                        Label(starred.contains(row) ? "★ \\(row)" : row)
                            .padding(14, 12)
                    }
                    .stroke(Palette.outline)
                    .strokeShape(.roundRectangle(8))
                    // The items are revealed BEHIND the content, so a row that
                    // does not paint itself shows them through.
                    .backgroundColor(Palette.surface)
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

                            lastAct = "Starred \\(row)"
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
                            lastAct = "Deleted \\(row)"
                        }
                }
                // Anything short of this springs back, which is what
                // onSwipeEnded reports as isOpen == false.
                .threshold(needed)
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

            // The other two collections, on a card tall enough for a vertical
            // swipe to travel in: DOWN reveals the top items, UP the bottom
            // ones.
            SwipeView {
                Border {
                    Label(archived ? "Archived" : "In the inbox")
                        .padding(14, 12)
                }
                .stroke(Palette.outline)
                .strokeShape(.roundRectangle(8))
                .backgroundColor(Palette.surface)
            }
            .topItems {
                SwipeItem("Archive")
                    .backgroundColor(.steelBlue)
                    .onInvoked {
                        archived = true
                        lastAct = "Archived the card"
                    }
            }
            .bottomItems {
                SwipeItem("Restore")
                    .backgroundColor(.forestGreen)
                    .onInvoked {
                        archived = false
                        lastAct = "Restored the card"
                    }
            }
            .heightRequest(90)

            Label(rows.isEmpty ? "Every row deleted" : lastAct)

            Label(travel)

            Button("Put them back")
                .isEnabled(rows.count < 3)
                .onClicked {
                    rows = ["Alpha", "Beta", "Gamma"]
                    lastAct = "Swipe a row"
                }
        }
        """

    /// How far each row has to travel before its items come out. The same
    /// items three times, so the difference is in the finger.
    private static let thresholds = ["Alpha": 20.0, "Beta": 80.0, "Gamma": 160.0]

    var content: Element {
        VStack {
            ForEach(rows) { row in
                let needed = Self.thresholds[row] ?? 20

                return SwipeView {
                    Border {
                        HStack {
                            Label(starred.contains(row) ? "★ \(row)" : row)
                                .fontSize(15)
                                .verticalOptions(.center)

                            Label("threshold \(Int(needed))")
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
                    // The items are revealed BEHIND the content, so a row that
                    // does not paint itself shows them through.
                    .backgroundColor(Palette.surface)
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
                // Alpha gives way at once, Gamma takes eight times as far.
                // Anything short of the threshold springs back, which is what
                // onSwipeEnded reports as isOpen == false.
                .threshold(needed)
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

            // The other two collections, on a card tall enough for a vertical
            // swipe to travel in: DOWN reveals the top items, UP the bottom
            // ones.
            SwipeView {
                Border {
                    VStack {
                        Label(archived ? "Archived" : "In the inbox")
                            .fontSize(15)

                        Label("swipe down to Archive, up to Restore")
                            .fontSize(12)
                            .textColor(Palette.subtle)
                    }
                    .spacing(4)
                    .padding(14, 12)
                    .verticalOptions(.center)
                }
                .stroke(Palette.outline)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(8))
                .backgroundColor(Palette.surface)
            }
            .topItems {
                SwipeItem("Archive")
                    .backgroundColor(.steelBlue)
                    .onInvoked {
                        archived = true
                        lastAct = "Archived the card"
                    }
            }
            .bottomItems {
                SwipeItem("Restore")
                    .backgroundColor(.forestGreen)
                    .onInvoked {
                        archived = false
                        lastAct = "Restored the card"
                    }
            }
            .heightRequest(90)

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
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("MAUI has FOUR collections, and each is named for the EDGE its items "
                + "come from rather than for the swipe that reveals them: the left items "
                + "come out under a swipe to the right, the top items under a swipe DOWN. "
                + "The rows use two of them, the card the other two.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`threshold` is how far the view has to travel before the items are "
                + "revealed - 20 units on Alpha, 80 on Beta, 160 on Gamma. A swipe that "
                + "stops short of it springs back with nothing revealed, which is what the "
                + "reading under the rows calls `sprang back`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The three swipe reports are about the SWIPE - it began, it has moved "
                + "this far, it ended open or sprang back - where an item's `onInvoked` is "
                + "about one item being chosen. The items are NOT views: a SwipeItem is a "
                + "MenuItem in MAUI - a caption, a picture, a colour and something to run - "
                + "so it takes its own modifiers and belongs in one of the four collections "
                + "and nowhere else.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS THIS NEEDS A FINGER: a swipe answers touch and pen and "
                + "not a mouse there. A desktop app that must work with a mouse wants a "
                + "context flyout or a button beside the row, not only a swipe.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
