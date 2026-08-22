import StateUI

/// The library's own carousel - a ScrollView that settles on a card.
struct CarouselViewSample: SampleContent {
    @State private var cards = ["Describe", "Diff", "Render"]
    @State private var shown = 0
    @State private var batches = 0
    @State private var sideways = true
    @State private var locked = false
    @State private var moved = "swipe it, or use the buttons"

    static let id = "carouselView"
    static let title = "CarouselView"
    static let summary = "One card at a time, swiped through - and settling on whichever is nearest."

    // A swipe is a gesture, and the page's own scroller would claim it before
    // the carousel heard about it - see SampleContent.scrolls.
    static let scrolls = false

    /// The example is given the WINDOW's height: the carousel's cards are cut
    /// from what is left after the dots and the buttons, so the box it gets is
    /// the whole point of the sample.
    static let fills = true

    static let code = """
        @State private var cards = ["Describe", "Diff", "Render"]
        @State private var shown = 0
        @State private var batches = 0
        @State private var sideways = true
        @State private var locked = false
        @State private var moved = "swipe it, or use the buttons"

        private static let all = ["Describe", "Diff", "Render"]

        Grid {
            CarouselView(cards, id: \\.self) { card in
                Border {
                    VStack {
                        Label(card)
                        Label("Card \\((cards.firstIndex(of: card) ?? 0) + 1) of \\(cards.count)")
                    }
                    .padding(20)
                }
                .stroke(Palette.accent)
                .strokeShape(.roundRectangle(12))
            }
            // Where it IS - written back by every settle, and moving the
            // carousel when something else assigns it.
            .position($shown)
            // Which way the cards run, and whether the reader may push them.
            .orientation(sideways ? .horizontal : .vertical)
            .isSwipeEnabled(!locked)
            // How much of the box the middle card takes; the rest is where the
            // neighbours show.
            .itemFraction(0.75)
            .spacing(12)
            // One card from the end, ask for more - and -1 would mean never.
            .remainingItemsThreshold(1)
            .onRemainingItemsThresholdReached {
                guard cards.count < 9 else { return }

                batches += 1
                cards += ["More \\(batches)"]
            }
            .onPositionChanged { at in moved = "settled on card \\(at + 1)" }
            .emptyView(Label("Nothing to leaf through - Refill brings the cards back."))

            // Joined to the carousel by the binding, not by naming it.
            IndicatorView()
                .count(cards.count)
                .position(shown)
                .gridRow(1)

            Label(moved)
                .gridRow(2)

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
            .gridRow(3)

            HStack {
                Button(sideways ? "Runs sideways" : "Runs down")
                    .onClicked { sideways.toggle() }

                Button(locked ? "Unlock swiping" : "Lock swiping")
                    .onClicked { locked.toggle() }
            }
            .gridRow(4)
        }
        // The carousel takes the STAR row, so a card is a fraction of whatever
        // the window leaves it - resize the window and the cards are recut.
        .rowDefinitions(.star, .auto, .auto, .auto, .auto)
        .rowSpacing(12)
        """

    private static let all = ["Describe", "Diff", "Render"]

    var content: Element {
        Grid {
            CarouselView(cards, id: \.self) { card in
                Border {
                    VStack {
                        Label(card)
                            .fontSize(20)
                            .fontAttributes(.bold)
                            .horizontalTextAlignment(.center)

                        Label("Card \((cards.firstIndex(of: card) ?? 0) + 1) of \(cards.count)")
                            .fontSize(13)
                            .textColor(Palette.subtle)
                            .horizontalTextAlignment(.center)
                    }
                    .spacing(6)
                    .padding(20)
                    .verticalOptions(.center)
                }
                .stroke(Palette.accent)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(12))
                .backgroundColor(Palette.surface)
            }
            .position($shown)
            .orientation(sideways ? .horizontal : .vertical)
            .isSwipeEnabled(!locked)
            .itemFraction(0.75)
            .spacing(12)
            .remainingItemsThreshold(1)
            .onRemainingItemsThresholdReached {
                guard cards.count < 9 else { return }

                batches += 1
                cards += ["More \(batches)"]
            }
            .onPositionChanged { at in moved = "settled on card \(at + 1)" }
            .emptyView(Label("Nothing to leaf through - Refill brings the cards back.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .horizontalOptions(.center)
                .verticalOptions(.center))

            // Joined to the carousel by the binding, not by naming it - the
            // dots are the IndicatorView sample's subject, and here they are
            // just how a reader sees where they are.
            IndicatorView()
                .count(cards.count)
                .position(shown)
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)
                .indicatorSize(8)
                .horizontalOptions(.center)
                .gridRow(1)

            Label(moved)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .gridRow(2)

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
            .gridRow(3)

            HStack {
                // The same cards, run the other way - the difference is the
                // direction and nothing else.
                Button(sideways ? "Runs sideways" : "Runs down")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { sideways.toggle() }

                // The reader's own swipe, taken away and given back.
                Button(locked ? "Unlock swiping" : "Lock swiping")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { locked.toggle() }
            }
            .spacing(10)
            .horizontalOptions(.center)
            .gridRow(4)
        }
        // The carousel takes the STAR row: a card is a fraction of whatever the
        // window leaves it, so resizing the window recuts the cards.
        .rowDefinitions(.star, .auto, .auto, .auto, .auto)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("This carousel is the library's own: a ScrollView with the cards placed by "
                + "arithmetic, and only the middle one and its neighbours described. While "
                + "a finger is on it the platform scrolls and nothing else interferes; "
                + "when the finger lifts, the platform says where its own deceleration "
                + "would stop and the card nearest THAT is brought to the middle in one "
                + "glide - a hard throw lands several cards on, a slow drag lands on the "
                + "next. Touch the carousel mid-glide and the glide stops under your "
                + "finger.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Swipe to the last card and the deck GROWS - `remainingItemsThreshold(1)` "
                + "asks for more one card from the end, and the new cards arrive where the "
                + "reader is rather than sending the carousel back to the first.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The middle card takes three quarters of the box, which is what leaves its "
                + "neighbours showing at the edges. The box is whatever the window leaves "
                + "after the dots and the buttons, so resizing the window recuts the cards - "
                + "and running them down shows the same arithmetic the other way.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
