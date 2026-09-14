import StateUI

/// Actions behind a row, revealed by a swipe from any of four edges.
struct SwipeViewSample: SampleContent, ExampleContent {
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
            // What a swipe is doing, and what the last one did, are read
            // here - so a swipe builds this closure each time `travel`
            // changes while the finger moves.
            DebugInfoLabel()

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
                    .background(Palette.surface)
                }
                // Revealed by swiping RIGHT: they come from the left edge.
                .leftItems {
                    SwipeAction(starred.contains(row) ? "Unstar" : "Star")
                        .background(.gold)
                        .onClicked {
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
                    SwipeAction("Delete")
                        .background(.firebrick)
                        .isDestructive(true)
                        .onClicked {
                            rows.removeAll { $0 == row }
                            starred.remove(row)
                            lastAct = "Deleted \\(row)"
                        }
                }
                // Anything short of this springs back, which is what
                // onSwipeEnded reports as isOpen == false.
                .threshold(needed)
                // The swipe ITSELF, where onClicked is one ITEM being chosen -
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
                .background(Palette.surface)
            }
            .topItems {
                SwipeAction("Archive")
                    .background(.steelBlue)
                    .onClicked {
                        archived = true
                        lastAct = "Archived the card"
                    }
            }
            .bottomItems {
                SwipeAction("Restore")
                    .background(.forestGreen)
                    .onClicked {
                        archived = false
                        lastAct = "Restored the card"
                    }
            }
            .height(90)

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

    var content: any View {
        VStack {
            DebugInfoLabel()

            ForEach(rows) { row in
                let needed = Self.thresholds[row] ?? 20

                return SwipeView {
                    Border {
                        HStack {
                            Label(starred.contains(row) ? "★ \(row)" : row)
                                .fontSize(15)
                                .verticalAlignment(.center)

                            Label("threshold \(Int(needed))")
                                .fontSize(12)
                                .textColor(Palette.subtle)
                                .horizontalAlignment(.end)
                                .verticalAlignment(.center)
                        }
                        .spacing(12)
                        .padding(14, 12)
                    }
                    .stroke(Palette.outline)
                    .strokeThickness(1)
                    .strokeShape(.roundRectangle(8))
                    // The items are revealed BEHIND the content, so a row that
                    // does not paint itself shows them through.
                    .background(Palette.surface)
                }
                // Revealed by swiping RIGHT: they come from the left-hand edge.
                .leftItems {
                    SwipeAction(starred.contains(row) ? "Unstar" : "Star")
                        .background(.gold)
                        .onClicked {
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
                    SwipeAction("Delete")
                        .background(.firebrick)
                        .isDestructive(true)
                        .onClicked {
                            rows.removeAll { $0 == row }
                            starred.remove(row)
                            lastAct = "Deleted \(row)"
                        }
                }
                // Alpha gives way at once, Gamma takes eight times as far.
                // Anything short of the threshold springs back, which is what
                // onSwipeEnded reports as isOpen == false.
                .threshold(needed)
                // The swipe ITSELF, where onClicked is one ITEM being
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
                    .verticalAlignment(.center)
                }
                .stroke(Palette.outline)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(8))
                .background(Palette.surface)
            }
            .topItems {
                SwipeAction("Archive")
                    .background(.steelBlue)
                    .onClicked {
                        archived = true
                        lastAct = "Archived the card"
                    }
            }
            .bottomItems {
                SwipeAction("Restore")
                    .background(.forestGreen)
                    .onClicked {
                        archived = false
                        lastAct = "Restored the card"
                    }
            }
            .height(90)

            Label(rows.isEmpty ? "Every row deleted" : lastAct)
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            Label(travel)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            Button("Put them back")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
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
            Label("A SwipeView has FOUR collections, and each is named for the EDGE its "
                + "items come from rather than for the swipe that reveals them: the left "
                + "items come out under a swipe to the right, the top items under a swipe "
                + "DOWN. The rows use two of them, the card the other two.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`threshold` is how far the view has to travel before the items are "
                + "revealed - 20 units on Alpha, 80 on Beta, 160 on Gamma. A swipe that "
                + "stops short of it springs back with nothing revealed, which is what the "
                + "reading under the rows calls `sprang back`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The three swipe reports are about the SWIPE - it began, it has moved "
                + "this far, it ended open or sprang back - where an item's `onClicked` is "
                + "about one item being chosen. The items are NOT views: a `SwipeAction` has "
                + "a caption, a picture, a colour and something to run, and no layout of "
                + "its own - so it takes its own modifiers and belongs in one of the four "
                + "collections and nowhere else.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
