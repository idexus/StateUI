import StateUI

/// Acting on a row by swiping it - the row IS a SwipeView.
struct SwipeRowsSample: SampleContent {
    @State private var items: [Int] = Array(1...200)
    @State private var pinned: Set<Int> = []

    static let id = "swipeRows"
    static let title = "Swipe a row"
    static let summary = "Deleting and pinning by swiping - the row is a SwipeView like any other."

    // The list scrolls itself, so the page holds still and scrolls the code.
    static let scrolls = false
    static let fills = true

    static let code = """
        @State private var items: [Int] = Array(1...200)
        @State private var pinned: Set<Int> = []

        // A STAR row is what gives the list its height: it takes whatever the
        // button above it leaves. Row 0 is the default, so only the list has
        // to say where it is.
        Grid {
            Button("Start over").onClicked {
                items = Array(1...200)
                pinned = []
            }

            // A row that acts on a swipe needs nothing from the list: the
            // template returns a SwipeView, which is MAUI's own control, and
            // the list places it like any other row.
            CollectionView(items) { number in
                SwipeView {
                    HStack {
                        Label(pinned.contains(number) ? "★" : "")
                        Label("Row \\(number)")
                    }
                }
                .leftItems {
                    SwipeItem(pinned.contains(number) ? "Unpin" : "Pin")
                        .onInvoked {
                            if pinned.contains(number) {
                                pinned.remove(number)
                            } else {
                                pinned.insert(number)
                            }
                        }
                }
                .rightItems {
                    SwipeItem("Delete")
                        .isDestructive(true)
                        .onInvoked {
                            items.removeAll { $0 == number }
                            pinned.remove(number)
                        }
                }
            }
            .itemSize(44)
            .emptyView(Label("Every row is gone - Start over brings them back."))
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        """

    var content: Element {
        Grid {
            HStack {
                Button("Start over")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        items = Array(1...200)
                        pinned = []
                    }

                Label("\(items.count) rows, \(pinned.count) pinned")
                    .fontSize(13)
                    .textColor(Palette.accent)
                    .verticalOptions(.center)
            }
            .spacing(12)
            .horizontalOptions(.center)
            .gridRow(0)

            CollectionView(items) { number in
                SwipeView {
                    HStack {
                        Label(pinned.contains(number) ? "★" : "")
                            .fontSize(14)
                            .textColor(Palette.accent)
                            .widthRequest(20)
                            .verticalOptions(.center)

                        Label("Row \(number)")
                            .fontSize(15)
                            .verticalOptions(.center)
                    }
                    .spacing(8)
                    .padding(14, 10)
                    .backgroundColor(Palette.surface)
                }
                .leftItems {
                    SwipeItem(pinned.contains(number) ? "Unpin" : "Pin")
                        .backgroundColor(Palette.accent)
                        .onInvoked {
                            if pinned.contains(number) {
                                pinned.remove(number)
                            } else {
                                pinned.insert(number)
                            }
                        }
                }
                .rightItems {
                    SwipeItem("Delete")
                        .isDestructive(true)
                        .onInvoked {
                            items.removeAll { $0 == number }
                            pinned.remove(number)
                        }
                }
            }
            .itemSize(44)
            .emptyView(Label("Every row is gone - Start over brings them back.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)
                .verticalOptions(.center))
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Swipe a row left for Delete, right for Pin. There is no swipe API on the "
                + "list at all: a row is a view, and a row that acts on a swipe is a "
                + "SwipeView around what it would have shown - MAUI's own control, with "
                + "MAUI's own items on it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The row's own background is not decoration: a SwipeView reveals its items "
                + "BEHIND the content, so content that does not paint itself shows them "
                + "through. And the swipe is sideways where the list scrolls down, which is "
                + "what keeps the two gestures out of each other's way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Delete takes the item out of the state, and the row goes with it - the "
                + "item is the row's identity, so nothing else moves. Take every row out and "
                + "the empty view stands in.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS THIS NEEDS A FINGER, and the list is fine: a swipe "
                + "answers touch and pen and not a mouse there, so the rows scroll and "
                + "draw perfectly while no mouse drag reveals an item.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
