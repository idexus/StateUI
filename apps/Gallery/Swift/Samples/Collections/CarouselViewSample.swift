import StateUI

/// MAUI: CarouselView, and the IndicatorView under it.
struct CarouselViewSample: SampleContent {
    @State private var shown = 0
    @State private var cards = ["Describe", "Diff", "Render"]
    @State private var batches = 0
    @State private var locked = false
    @State private var glides = true
    @State private var sideways = true
    @State private var moved = "swipe, or use the buttons"

    static let id = "carouselView"
    static let title = "CarouselView"
    static let summary = "One item at a time, swiped through - and the dots that say where you are."

    // A swipe is a gesture, and the page's own scroller would claim it before
    // the carousel heard about it - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var shown = 0
        @State private var cards = ["Describe", "Diff", "Render"]
        @State private var batches = 0
        @State private var locked = false
        @State private var glides = true
        @State private var sideways = true
        @State private var moved = "swipe, or use the buttons"

        private static let all = ["Describe", "Diff", "Render"]

        VStack {
            CarouselView {
                ForEach(Array(cards.enumerated()), id: \\.offset) { pair in
                    let (index, card) = pair
                    return Border {
                        VStack {
                            Label(card)
                            Label("Step \\(index + 1) of \\(cards.count)")
                        }
                        .padding(24)
                    }
                    .stroke(Palette.accent)
                    .strokeShape(.roundRectangle(12))
                    .margin(8)
                    .id(card)
                }
            }
            .emptyView(Label("Nothing to leaf through - Refill brings the cards back."))
            .position($shown)
            .loop(false)
            .peekAreaInsets(Thickness(40))
            // Which way it runs. A carousel shows one item at a time, so the
            // two LIST layouts are the choice - a grid is not one of them.
            .itemsLayout(sideways ? .horizontalList : .verticalList)
            // Whether the READER may move it, whether a move this side makes
            // glides or jumps, and how far past the ends it may be pulled.
            .isSwipeEnabled(!locked)
            .isScrollAnimated(glides)
            .isBounceEnabled(!locked)
            .horizontalScrollBarVisibility(.never)
            .onPositionChanged { at in moved = "moved to card \\(at + 1)" }
            // One card from the end, ask for more - the same convention a
            // LazyList follows, and -1 would mean never.
            .remainingItemsThreshold(1)
            .onRemainingItemsThresholdReached {
                guard cards.count < 9 else { return }

                batches += 1
                cards += ["More \\(batches)"]
            }
            .heightRequest(160)

            // Joined to the carousel by the binding, not by naming it.
            IndicatorView()
                .count(cards.count)
                .position(shown)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .indicatorSize(8)

            // The same dots as VIEWS - MAUI's IndicatorTemplate, run here:
            // each dot is whatever the closure says, and the current one is
            // the author's to draw, reading the same state. Android draws
            // them (and paints the dot colours behind them); iOS and Mac
            // Catalyst draw MAUI's own dots only - measured.
            IndicatorView(cards.indices) { index in
                Label(index == shown ? "X" : "O")
                    .id("dot\\(index)")
            }
            .position(shown)

            HStack {
                Button("Back")
                    .isEnabled(shown > 0)
                    .onClicked { shown -= 1 }

                Button("Next")
                    .isEnabled(shown < cards.count - 1)
                    .onClicked { shown += 1 }

                Button(cards.isEmpty ? "Refill" : "Clear")
                    .onClicked {
                        shown = 0
                        cards = cards.isEmpty ? Self.all : []
                    }
            }
        }
        """

    private static let all = ["Describe", "Diff", "Render"]

    var content: Element {
        VStack {
            CarouselView {
                ForEach(Array(cards.enumerated()), id: \.offset) { pair in
                    let (index, card) = pair
                    return Border {
                        VStack {
                            Label(card)
                                .fontSize(20)
                                .fontAttributes(.bold)
                                .horizontalTextAlignment(.center)

                            Label("Step \(index + 1) of \(cards.count)")
                                .fontSize(13)
                                .textColor(Palette.subtle)
                                .horizontalTextAlignment(.center)
                        }
                        .spacing(6)
                        .padding(24)
                    }
                    .stroke(Palette.accent)
                    .strokeThickness(1)
                    .strokeShape(.roundRectangle(12))
                    .margin(8)
                    .id(card)
                }
            }
            .emptyView(Label("Nothing to leaf through - Refill brings the cards back.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .padding(24, 0)
                .horizontalOptions(.center)
                .verticalOptions(.center))
            .position($shown)
            .loop(false)
            .peekAreaInsets(Thickness(40))
            // Which way it runs. A carousel shows one item at a time, so the
            // two LIST layouts are the choice - a grid is not one of them.
            .itemsLayout(sideways ? .horizontalList : .verticalList)
            // Whether the READER may move it, whether a move this side makes
            // glides or jumps, and how far past the ends it may be pulled.
            .isSwipeEnabled(!locked)
            .isScrollAnimated(glides)
            .isBounceEnabled(!locked)
            .horizontalScrollBarVisibility(.never)
            .onPositionChanged { at in moved = "moved to card \(at + 1)" }
            // One card from the end, ask for more - the same convention a
            // LazyList follows, and -1 would mean never.
            .remainingItemsThreshold(1)
            .onRemainingItemsThresholdReached {
                guard cards.count < 9 else { return }

                batches += 1
                cards += ["More \(batches)"]
            }
            .heightRequest(160)

            IndicatorView()
                .count(cards.count)
                .position(shown)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .indicatorSize(8)
                .horizontalOptions(.center)

            IndicatorView(cards.indices) { index in
                Label(index == shown ? "X" : "O")
                    .fontSize(13)
                    .fontAttributes(.bold)
                    .textColor(index == shown ? Palette.onAccent : Palette.subtle)
                    .id("dot\(index)")
            }
            .position(shown)
            .horizontalOptions(.center)

            HStack {
                Button("Back")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(shown > 0)
                    .onClicked { shown -= 1 }

                Button("Next")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(shown < cards.count - 1)
                    .onClicked { shown += 1 }

                Button(cards.isEmpty ? "Refill" : "Clear")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        shown = 0
                        cards = cards.isEmpty ? Self.all : []
                    }
            }
            .spacing(10)
            .horizontalOptions(.center)

            HStack {
                // The same Back and Next buttons, gliding or jumping.
                Button(glides ? "Moves glide" : "Moves jump")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { glides.toggle() }

                // Which way the cards run - the same cards, swiped the other
                // way, so the difference is the direction and nothing else.
                Button(sideways ? "Runs sideways" : "Runs down")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { sideways.toggle() }

                // The reader's own swipe, and the pull past the ends with it.
                Button(locked ? "Unlock swiping" : "Lock swiping")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { locked.toggle() }
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label(moved)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The items are children, the way a LazyList's rows are: no ItemsSource, "
                + "no DataTemplate, no binding context. Clear takes them all away, which "
                + "is what the emptyView is for - and Refill starts the deck over.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("MAUI joins an IndicatorView to a carousel by naming the control, and a "
                + "property that names a control needs a registry this side does not have. "
                + "Both take a position, so one @State does the same work - and the buttons "
                + "write to that same state, which is why they move the carousel too.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The second row of dots is MAUI's IndicatorTemplate, run in Swift: each "
                + "dot is a view the closure described, so the current one is the author's "
                + "to draw - it reads the same state the carousel writes. Measured: ANDROID "
                + "and WINDOWS draw the described dots and still paint the dot colours "
                + "behind them, the current one wearing the selected colour as its "
                + "background - while iOS and Mac Catalyst draw MAUI's own dots only, the "
                + "template never reaching the screen there.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
