// Where the gallery opens.

import StateUI

/// What this is, and every group there is.
///
/// The one page that names the whole catalog, so a reader who has never seen the
/// library can find the control they came for without opening the flyout. The
/// groups are a GALLERY: one card each, swiped through, and the card in the
/// middle says underneath what is in it and opens when it is tapped.
struct HomePage: GalleryPage {
    let catalog: Catalog

    /// Where the gallery is - a card switches the section.
    let nav: Navigation

    /// Which group's card is in the middle. The gallery writes it as the reader
    /// swipes, so the words under the cards follow the hand.
    @State private var chosen = 0

    /// The device's facts, resolved from the standard environment - the
    /// idiom for the count, and the footer's word.
    @Environment var device: DeviceInfo

    /// The screen, which decides whether a phone is on its side.
    @Environment var display: DeviceDisplay

    /// How tall the page's own room is, as it was last measured.
    ///
    /// NOTHING IS LAID OUT FROM THIS. Every size on the page is arithmetic
    /// over the room the `FrameReader` hands its closure, which is a value
    /// read where it is used rather than one kept - so a report that never
    /// arrives leaves nothing stale behind it. This copy steers ONE thing:
    /// when the page has held still long enough to be worth showing.
    @State private var cell = 0.0

    /// How far the page has come in.
    ///
    /// THE ROOM IS NOT KNOWN UNTIL IT IS MEASURED, and this page is arranged
    /// FROM that measurement: the cards' box is what the star row can spare,
    /// which the star row cannot say until it has been laid out. So the first
    /// arrangement is a guess, the second is the answer, and the step between
    /// them is a jump - not in the cards alone, but in everything standing
    /// under them.
    ///
    /// Rather than hide the step, the page arrives once it is over.
    @State private var shown = 0.0

    var title: String? { "Home" }

    /// No home button: this is it. The bar and everything else about the page is
    /// the house style, which is why this is the one thing overridden.
    var toolbarItems: [ToolbarItem] { [] }

    var content: Element {
        let groups = catalog.groups
        let at = min(max(chosen, 0), max(groups.count - 1, 0))
        let group = groups[at]

        // THE PAGE'S OWN ROOM, and every size below is arithmetic over it.
        //
        // The reader FILLS what the page gives it, which is what makes the
        // number safe to build from: a measurement its own content can grow
        // is a measure that feeds itself, and it hangs the process. Nothing
        // inside asks for more than the room - the run is fitted to what is
        // left and the heading is shown only where it fits - so the room the
        // closure is handed is the page's, first pass and every pass after.
        return FrameReader { room in
            // What the rows have to share, once the page's own margin is out.
            let usable = room.height - 2 * Self.margin

            // WHAT IS LEFT FOR THE CARDS once the heading, the gap and the
            // words have theirs - the one number every choice below is made
            // from, and arithmetic over stated heights rather than a second
            // measurement.
            let spare = usable - Self.heading - Self.gap - Self.words

            // THE HEADING STANDS WHILE WHAT IT LEAVES IS STILL A RUN WORTH
            // DRAWING. It is the page saying what it is, which is why it goes
            // last rather than first: a phone's room holds it and a run at
            // about half its ceiling, and that is a better page than cards
            // alone. Only where the run would be smaller than it is worth
            // drawing at do the cards take the whole room.
            let heading = headerShows && spare >= Self.least

            // AND THE TWO LINES AT THE FOOT go after both, being what a reader
            // reads once they have found the cards. They cost the run their
            // own height, so they stand only where it can spare it AND still
            // reach its ceiling - a page that had to shrink the cards has
            // nothing to add at the bottom.
            let foot = footFits && heading
                && spare - Self.gap - Self.footer >= Self.gallery

            // The run takes what is left, up to its own ceiling.
            let box = max(
                min(heading ? spare : usable - Self.words, Self.gallery),
                Self.least)

            // A GRID OF THREE ROWS: the heading takes what it needs, the run
            // of cards takes what is LEFT, and the two lines about what this
            // is sit at the foot.
            //
            // ONE GRID RATHER THAN A BRANCH PER SHAPE. An `if` in a builder
            // is a branch KEY, so a page that crossed the threshold would
            // destroy the run of cards and build it again; a row whose view
            // is not visible collapses to nothing, and the pair - centred in
            // the star row - then stands in the middle of the page by itself.
            Grid {
                VStack {

                // The mark, the name and what it is, on the identity gradient -
                // the one place in the app that says all three at once.
                //
                // The panel paints its own background and its own edge: the
                // implicit Border style fills a card and draws a hairline, and
                // both would show through the gradient.
                Border {
                    VStack {
                        Image("stateui_mark.png")
                            .widthRequest(84)
                            .heightRequest(84)
                            .horizontalOptions(.start)

                        Label("StateUI Gallery")
                            .fontSize(34)
                            .fontAttributes(.bold)
                            .characterSpacing(-0.5)
                            .textColor(Palette.onBrand)

                        Label("MAUI interfaces, written in Swift")
                            .fontSize(15)
                            .textColor(Palette.onBrand)
                            .opacity(0.85)
                    }
                    .spacing(10)
                    .padding(22)
                }
                .background(Palette.identity)
                .stroke(.transparent)
                .strokeThickness(0)
                .strokeShape(.roundRectangle(18))

                SectionTitle("\(catalog.sampleCount(on: device.idiom)) SAMPLES "
                    + "IN \(groups.count) GROUPS")
            }
            .spacing(14)
            .verticalOptions(.start)
            // A PHONE ON ITS SIDE has no height for a heading: the cards are
            // what the page is for, so they are what it keeps.
            .isVisible(heading)
            .gridRow(0)

            VStack {
                // ONE CARD PER GROUP, turned by a finger, a trackpad or a
                // wheel. Nothing here is described while the run moves: the
                // gallery's arithmetic follows the scroller on the host's own
                // frames, and the one render is the card CHANGING - which is
                // what the words below are written from.
                GalleryView(groups, id: \.route) { group in
                    face(group)
                }
                .position($chosen)
                .onItemTapped { group in nav.push(.group(group.route)) }
                // A SIZE WORKED OUT FROM A MEASUREMENT DOES NOT TRAVEL. `box`
                // is read off the star row's own frame, so it is a value the
                // PLATFORM reports rather than one anybody chose - and carried
                // by the library's default motion it crawled to its answer
                // over half a second (measured: 204, 361.5, 378.3, 390.1,
                // 396.1, 399.0, 399.9, 400), with the words under the run
                // riding every step of it.
                .heightRequest(box)
                .motion(.none)

                // WHAT THE CARD IN THE MIDDLE IS, in the words its own face
                // has no room for. The NAME is not among them: the card
                // carries it, and saying it again a card's width below reads
                // as two things rather than one.
                //
                // THE BLOCK IS ONE HEIGHT WHATEVER IT SAYS, and the words
                // inside it are not cut to make that true. The summaries are
                // sentences of different lengths, so left to itself this
                // block is one line taller under one card than the next - and
                // its height is what the star row above it has LEFT to give
                // the run. A reader swiping would then resize the gallery
                // from card to card, which lays the whole page out afresh and
                // moves everything under it.
                //
                // So the block is given the room the longest of them needs
                // and the words stand at the TOP of it: every summary wraps
                // to as many lines as it wants, the count sits under it, and
                // what changes between cards is how much of the block is
                // empty underneath rather than how tall it is.
                VStack {
                    Label("\(group.shown(on: device.idiom).count) samples · tap the "
                        + "card to open")
                        .fontSize(12)
                        .textColor(Palette.accent)
                        .horizontalTextAlignment(.center)

                    Label(group.summary)
                        .fontSize(14)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
                .heightRequest(Self.caption)
                .verticalOptions(.start)
            }
            .spacing(Self.gap)
            .verticalOptions(.center)
            .gridRow(1)

            // WHAT THIS IS, at the FOOT of the page and centred: the cards are
            // what a reader came for, and these two lines are what they read
            // once they have found it. They go completely when the cards' cell
            // runs short - an auto row keeps its height whatever is left, and
            // words that no longer fit would be drawn OVER what is above them.
            VStack {
                Label("Every example here is described in Swift and rendered as real "
                    + "MAUI controls.")
                    .fontSize(15)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)

                // The platform is compiled in; the idiom - phone, tablet,
                // desktop - is the host's answer, which is what lets the
                // catalog list desktop chrome only where it draws.
                Label("native: \(stateUIPlatform()) · \(device.idiom)")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(4)
            .isVisible(foot)
            .gridRow(2)
        }
            .rowDefinitions(.auto, .star, .auto)
            .rowSpacing(Self.gap)
            // INSIDE the reader, which is what makes the margin the rows' own
            // to lose: the frame the closure is handed is this view's outer
            // one, so `usable` takes the margin off explicitly.
            .padding(Self.margin, Self.margin)
        }
        .opacity($shown)
        // WHAT THE ENTRANCE WAITS FOR, and the only thing this number is for.
        // Nothing above is laid out from it - the rows are arithmetic over the
        // room the reader hands its closure - so a report that never lands
        // leaves the page correct and merely early.
        .onFrameChanged { frame in
            guard abs(frame.height - cell) > 1 else { return }

            cell = frame.height
        }
        // THE PAGE COMES IN ONCE THE ROOM HAS ANSWERED. Everything here is
        // arranged FROM the measurement above - the cards' box is what the
        // page can spare - so the first arrangement is a guess and the second
        // is the answer, and the step between them is a jump in the cards and
        // in everything standing under them.
        //
        // On LOADED rather than on the measurement changing: the watch is
        // written on this very view, so the render that moves the number is
        // the one that rebuilds the watch, and a watch rebuilt is a watch that
        // starts over rather than firing. Waiting for the number here is one
        // line and cannot miss it.
        .onLoaded {
            guard shown == 0 else { return }

            // THE FADE BEGINS WHEN THE ROOM HAS SETTLED: the measurement
            // moves for as long as the first arrangement is still being
            // worked out, so the page arrives once it has held still - or
            // after a bound either way, an entrance being worth less than a
            // page nobody can see.
            var waited = 0
            var held = 0.0
            var still = 0

            while still < Self.steady, waited < Self.patience {
                try await Task.sleep(for: .milliseconds(Self.beat))
                waited += Self.beat

                if cell > 0, cell == held { still += Self.beat } else { still = 0 }

                held = cell
            }

            try await $shown.animateTo(1, .eased(Self.entrance, .cubicOut))
        }
    }

    /// How long the measurement has to hold still before the page takes it
    /// as settled, in milliseconds.
    private static var steady: Int { 240 }

    /// How often the page looks to see whether its room has been measured, in
    /// milliseconds.
    private static var beat: Int { 20 }

    /// How long it is worth waiting for a measurement at all, in milliseconds
    /// - past which the page simply arrives, an entrance being worth less than
    /// a page nobody can see.
    private static var patience: Int { 1500 }

    /// How long the page takes to come in, in milliseconds.
    private static var entrance: UInt { 700 }

    /// Whether the heading shows at all: not on a phone on its side, which has
    /// no height to give it - the cards alone are the page there, and the two
    /// lines at the foot go with it.
    private var headerShows: Bool {
        !(device.idiom == .phone && display.orientation == .landscape)
    }

    /// Whether the two lines at the foot belong on this device at all.
    ///
    /// Not on a PHONE. Its cell is under the threshold at every size, so the
    /// lines are shown by the first render and taken away by the first
    /// measurement - which is a flash, and a resize of everything above them
    /// for nothing. Where there is never room, the answer is not to ask.
    private var footFits: Bool {
        device.idiom != .phone
    }

    /// The page's own margin, which the rows do not get to share.
    private static var margin: Double { 24 }

    /// How tall the block that says what this is stands - the mark, the name,
    /// the sentence under it and the count.
    ///
    /// STATED RATHER THAN MEASURED, for the reason `caption` is: the room
    /// left for the cards is what this block does not take, so measuring it
    /// would size the run from something the run's own layout can move.
    /// Rounded UP, so a font a platform draws a little larger costs the page
    /// nothing but a few points of slack.
    private static var heading: Double { 250 }

    /// A run of cards at its largest - the gallery's own ceiling.
    private static var gallery: Double { 400 }

    /// The two lines at the foot, their gap included - both what they take out
    /// of the page and what they give it back by going.
    private static var footer: Double { 54 }

    /// How tall the words under the run are - room for a summary of up to
    /// three lines and the count, at the sizes above.
    ///
    /// STATED RATHER THAN MEASURED, which is the whole point: a summary is a
    /// sentence, sentences differ in length, and a block left to its own
    /// height is a different height under every card. The run's room is what
    /// this block leaves, so that would resize the gallery on every swipe.
    /// Room for the longest rather than a cut to fit the shortest - nothing
    /// here is truncated, and a card whose summary is one line simply leaves
    /// the bottom of the block empty.
    private static var caption: Double { 88 }

    /// The gap between the run and the words under it.
    private static var gap: Double { 12 }

    /// What the words under the cards take out of the pair's room, the gap
    /// joining them included.
    private static var words: Double { caption + gap }

    /// The smallest a run of cards is worth drawing at.
    private static var least: Double { 150 }



    /// One group's card - its picture and its name, and nothing about where the
    /// card goes or which way it faces. That is the gallery's, and keeping the
    /// two apart is what lets one run of cards wear any shape.
    private func face(_ group: SampleGroup) -> Element {
        Border {
            Grid {
                Image(group.card)
                    .aspect(.aspectFill)

                Grid {
                    Label(group.title)
                        .fontSize(18)
                        .fontAttributes(.bold)
                        .textColor(Palette.onBrand)
                        .lineBreakMode(.tailTruncation)
                        .padding(12, 10)
                        
                }
                .backgroundColor(Color("#B3000000"))
                .verticalOptions(.end)
            }
            // THE PICTURE IS CUT AT THE CARD'S EDGE, and this is a platform
            // difference rather than a nicety: a Border clips what it holds on
            // Apple and does not on Android, so a picture told to FILL the card
            // is painted at its own size all over the layout. The clip belongs
            // on the grid, which is a layout and therefore the thing that has
            // edges to cut at.
            .isClippedToBounds(true)
        }
        .strokeThickness(0)
        .strokeShape(.roundRectangle(16))
    }
}
