import StateUI

/// This library's own carousel - what stands in for MAUI's CarouselView here.
struct CarouselViewSample: SampleContent {
    @State private var cards = ["Describe", "Diff", "Render"]
    @State private var shown = 0
    @State private var batches = 0
    @State private var sideways = true
    @State private var locked = false
    @State private var stepped = false
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
        @State private var stepped = false
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
            // Nothing, and a swipe goes as far as it was thrown; 1, and it
            // moves exactly one card however hard it was thrown.
            .snapsAtMost(stepped ? 1 : 0)
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

            // An option is a switch, never a button whose caption changes.
            HStack {
                SwitchRow("Runs sideways", $sideways)
                SwitchRow("Swiping locked", $locked)
                SwitchRow("One card a swipe", $stepped)
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
            // Nothing, and a swipe goes as far as it was thrown; 1, and it
            // moves exactly one card however hard it was thrown.
            .snapsAtMost(stepped ? 1 : 0)
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

            Options {
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
            .gridRow(3)

            Options {
                // The same cards, run the other way - the difference is the
                // direction and nothing else.
                SwitchRow("Runs sideways", $sideways)

                // The reader's own swipe, taken away and given back.
                SwitchRow("Swiping locked", $locked)

                // How far one swipe may carry, whatever it was thrown at.
                SwitchRow("One card a swipe", $stepped)
            }
            .gridRow(4)
        }
        // The carousel takes the STAR row: a card is a fraction of whatever the
        // window leaves it, so resizing the window recuts the cards.
        .rowDefinitions(.star, .auto, .auto, .auto, .auto)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("One card at a time, with its neighbours showing at the edges. This is "
                + "the library's own control rather than MAUI's, written in Swift and the "
                + "same on every platform.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.position($shown)` is where it is: it is written back as you swipe, and "
                + "assigning it moves the carousel - which is what Back and Next do, and "
                + "what joins the dots above them. `.onPositionChanged` reports the card it "
                + "settled on. `.orientation(.vertical)` runs the cards downwards, and "
                + "`.isSwipeEnabled(false)` takes the swipe away while the buttons still "
                + "move it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.snapsAtMost(1)` holds a swipe to a single card however hard it is "
                + "thrown - what a deck being stepped through wants, against one being "
                + "leafed through. Throw it hard with each setting and watch how far it "
                + "goes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.remainingItemsThreshold(1)` asks for more cards one card from the end, "
                + "so swiping towards the last one GROWS the deck - up to nine here. Clear "
                + "empties it and shows the `.emptyView`; Refill puts the three back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.itemFraction(0.75)` gives the middle card three quarters of the box and "
                + "`.spacing(12)` the gap between cards, which is what leaves the "
                + "neighbours visible. The box is whatever the window leaves, so resizing "
                + "it recuts the cards.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS A SWIPE DOES NOT SETTLE ON A CARD: a desktop scrolls with a "
                + "wheel or a touchpad, which the platform gives no predicted stop to aim, "
                + "so the deck keeps the platform's own scrolling. Back and Next move it a "
                + "card at a time there, and the dots still follow it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
