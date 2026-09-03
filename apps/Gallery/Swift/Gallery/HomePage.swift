// Where the gallery opens.

import StateUI

/// What this is, and every group there is.
///
/// The one page that names the whole catalog, so a reader who has never seen the
/// library can find the control they came for without opening the flyout. The
/// groups are a GALLERY: one card each, swiped through, and the card in the
/// middle says underneath what is in it and opens when it is tapped.
///
/// **THE PAGE IS ARRANGED FROM ITS OWN MEASUREMENT**, which is the interesting
/// thing about it and the reason it is written the way it is. The run of cards
/// is given what the rows can spare, and what they can spare is not known until
/// the page has been laid out - so the measurement is read TWICE, by two roads,
/// because the two answers are different in kind. How TALL the run stands moves
/// with every pass the layout settles through and is worn rather than drawn, so
/// it is `.frame` into a driven state and `.following` over it: no render, on
/// the host's own frames. WHICH ROWS THERE ARE is described, so it renders -
/// but only when a reader turns the device or drags the window past a
/// threshold, which is a handful of times in a session rather than a handful of
/// times a second.
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

    /// The page's own room, as the platform lays it out.
    ///
    /// DRIVEN, so the host writes it on its own frames and nothing is built
    /// again for it. Two things read it: the engine below, which is what sizes
    /// the run, and the entrance, which waits for it to hold still.
    @State(describing: .none) private var room = Rect(0, 0, 0, 0)

    /// How tall the run of cards stands, which the engine below answers.
    ///
    /// A SIZE WORKED OUT FROM A MEASUREMENT DOES NOT TRAVEL, and here that is
    /// the shape of the value rather than a word beside it: an `AnimatedValue`
    /// made from one number is already standing at it, so every write the
    /// engine makes is an arrival. Carried by the library's default motion this
    /// number crawled to its answer over half a second, with everything under
    /// the run riding every step of it.
    @State(describing: .none) private var box = AnimatedValue(HomePage.gallery)

    /// How much of the page stands beside the cards.
    ///
    /// THE ONE THING THE MEASUREMENT DECIDES THAT IS DESCRIBED, which is why it
    /// is the one thing about the room that renders. A row that is not there is
    /// not a size, so no driven value can say it.
    @State private var chrome = Chrome.full

    /// How far the page has come in.
    ///
    /// THE ROOM IS NOT KNOWN UNTIL IT IS MEASURED, and this page is arranged
    /// FROM that measurement: the cards' box is what the star row can spare,
    /// which the star row cannot say until it has been laid out. So the first
    /// arrangement is a guess, the second is the answer, and the step between
    /// them is a jump - not in the cards alone, but in everything standing
    /// under them.
    ///
    /// Rather than hide the step, the page arrives once it is over - and
    /// DRIVEN, so the engine below both decides when that is and starts it,
    /// in the same cycle and without a render either side of it.
    @State(describing: .none) private var shown = AnimatedValue(0.0)

    /// Where the entrance has got to.
    ///
    /// A `@CycleState` is what an engine remembers between cycles: kept by
    /// property name across renders, read and written by the arithmetic alone,
    /// and describing nothing.
    @CycleState private var phase = Phase(Entrance.measuring)

    /// The room as the cycle before this one saw it, which is what "held
    /// still" is measured against.
    @CycleState private var held = Rect(0, 0, 0, 0)

    /// How long the entrance has waited altogether, in milliseconds.
    ///
    /// COUNTED ACROSS EVERY STEP, where `phase.elapsed` counts within one: a
    /// room that moves re-enters the step and starts its clock over, so the
    /// step alone could never run out of patience.
    @CycleState private var waited = 0.0

    var title: String? { "Home" }

    /// No home button: this is it. The bar and everything else about the page is
    /// the house style, which is why this is the one thing overridden.
    var toolbarItems: [ToolbarItem] { [] }

    var content: Element {
        let groups = catalog.groups
        let at = min(max(chosen, 0), max(groups.count - 1, 0))
        let group = groups[at]

        // THE CEILING AND THE CHROME ARE READ HERE, in the body, and handed to
        // the arithmetic below rather than looked up inside it. A read an
        // ENGINE makes is recorded NOWHERE - it runs on the host's own frames,
        // outside every render - so a value only the engine looked at would
        // move with nothing built again, and the run would stand at the height
        // the last shape gave it.
        let ceiling = affords
        let wearing = chrome

        // A GRID OF THREE ROWS: the heading takes what it needs, the run of
        // cards takes what is LEFT, and the two lines about what this is sit at
        // the foot.
        //
        // ONE GRID RATHER THAN A BRANCH PER SHAPE. An `if` in a builder is a
        // branch KEY, so a page that crossed the threshold would destroy the
        // run of cards and build it again; a row whose view is not visible
        // collapses to nothing, and the pair - centred in the star row - then
        // stands in the middle of the page by itself.
        return Grid {
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
            .isVisible(wearing.heads)
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
                // THE FAR CARDS DARKEN RATHER THAN FADE. A faded card here
                // would show the card BEHIND it - the wheel stands them one
                // over another - so what reads as depth is a shade over the
                // card rather than the card going transparent. It wears the
                // card's own corners, which is why the view is the
                // application's to give.
                .shade(BoxView(Color("#000000")).cornerRadius(16))
                // WHAT THE ROWS CAN SPARE, worn on the host's own frames. The
                // number is written by the engine under this grid, so a page
                // settling through half a dozen passes costs no render at all.
                .heightRequest($box)

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
            .isVisible(wearing.foots)
            .gridRow(2)
        }
        .rowDefinitions(.auto, .star, .auto)
        .rowSpacing(Self.gap)
        // The margin is the rows' own to lose: the frame below is this grid's
        // outer one, so the arithmetic takes the margin off explicitly.
        .padding(Self.margin, Self.margin)
        // THE PAGE'S OWN ROOM, written by the host and read by the arithmetic
        // that sizes the run. Nothing is built for it, which is the whole
        // difference between this and measuring a page with a `FrameReader`:
        // the run's height then rode a render per settling pass, and everything
        // standing under it rode them too.
        .frame($room)
        .following($room) { cycle in
            // NOTHING IS DECIDED FROM A ROOM NOBODY HAS MEASURED. Every render
            // arms every engine, so this runs once over the room as DECLARED -
            // before any layout has happened - and the host writes a frame
            // only once the platform has really laid the view out. Until then
            // the number holds what is written beside it, and there is nothing
            // here to work out.
            if room.height > 0 {
                // A SIZE WORKED OUT FROM A MEASUREMENT DOES NOT TRAVEL, and an
                // `AnimatedValue` made from one number is already standing at
                // it - so the write is an arrival rather than a journey. Sent
                // as a set point instead, this number crawled to its answer
                // over half a second with everything under the run riding
                // every step of it.
                box = AnimatedValue(Self.fitted(in: room, at: ceiling).run)
            }

            guard phase.current == .measuring else { return .still }

            waited += cycle.elapsed

            // THE ROOM MOVING RE-ENTERS THE STEP, and a re-entered step starts
            // its clock over: what is being waited for is a measurement that
            // has HELD STILL, not one that has merely arrived.
            if room != held {
                held = room
                phase.go(to: .measuring)
            }

            let settled = room.height > 0 && phase.elapsed(cycle) >= Self.steady

            // AND PATIENCE IS THE OTHER BOUND. An entrance is worth less than a
            // page nobody can see, so a room that never settles - or never
            // arrives at all - must not hold the page at nothing for ever.
            // Keeping it is the engine's OWN business: an engine that answers
            // `.moving` holds the display's clock open, and nothing else will
            // ever put it still.
            guard settled || waited >= Self.patience else { return .moving }

            shown.motion = .eased(Self.entrance, .cubicOut)
            shown.setPoint = 1
            phase.go(to: .arriving)

            return .still
        }
        // AND THE SAME MEASUREMENT AGAIN, for the one answer that is DRAWN
        // rather than worn. A driven value read in a body is a read nothing
        // records, so a row's presence cannot be taken from `room`: it needs a
        // report the tree hears. This one is quiet - it writes only where the
        // answer actually flips, which a reader does by turning the device or
        // dragging the window past a threshold.
        //
        // IT IS ALSO WHAT MARKS THE PAGE MEASURED, and that is the half worth
        // knowing: a WATCHED frame is what tells the arranger to place this
        // page's rows at once instead of carrying them, and only a watcher
        // sets it - the driven feed above does not. Take this away and the
        // rows travel through the very measurement that decides them.
        .onFrameChanged { frame in
            let answer = Self.fitted(in: frame, at: ceiling).chrome
            guard answer != chrome else { return }

            chrome = answer
        }
        .opacity($shown)
    }

    /// Where the page is in coming in.
    private enum Entrance {
        /// Waiting for the room to hold still.
        case measuring

        /// The fade is running, and the engine has nothing left to do.
        case arriving
    }

    /// How much of the page stands beside the run of cards.
    private enum Chrome {
        /// The heading, the cards, and the two lines at the foot.
        case full

        /// The heading and the cards - the room has nothing to spare below.
        case heading

        /// The cards alone, which is what a phone on its side is.
        case cards

        /// Whether the block that says what this is stands.
        var heads: Bool { self != .cards }

        /// Whether the two lines at the foot stand.
        var foots: Bool { self == .full }
    }

    /// The most chrome this DEVICE carries, before any room is measured.
    ///
    /// A phone on its side has no height for a heading. And the two lines at the
    /// foot are not a phone's at any size: its room is under the threshold
    /// however it is held, so asking would show them on the first render and
    /// take them away on the first measurement - which is a flash, and a resize
    /// of everything above them for nothing. Where there is never room, the
    /// answer is not to ask.
    private var affords: Chrome {
        guard device.idiom == .phone else { return .full }

        return display.orientation == .landscape ? .cards : .heading
    }

    /// What the room holds, and how tall the run of cards stands in it.
    ///
    /// ONE FUNCTION BECAUSE TWO READERS ASK IT: the engine takes the height and
    /// the frame watcher takes the chrome. Answered apart they could disagree -
    /// a run sized for a heading no longer described overflows the row it
    /// stands in, and the words under it are what goes off the bottom.
    ///
    /// - Parameters:
    ///   - room: the page's own frame, as the platform laid it out.
    ///   - most: the most chrome this device carries.
    /// - Returns: the chrome that fits, and how tall the run stands.
    private static func fitted(in room: Rect, at most: Chrome) -> (chrome: Chrome, run: Double) {
        // What the rows have to share, once the page's own margin is out.
        let usable = room.height - 2 * margin

        // WHAT IS LEFT FOR THE CARDS once the heading, the gap and the words
        // have theirs - the one number every choice below is made from, and
        // arithmetic over stated heights rather than a second measurement.
        let spare = usable - heading - gap - words

        // THE HEADING STANDS WHILE WHAT IT LEAVES IS STILL A RUN WORTH DRAWING.
        // It is the page saying what it is, which is why it goes last rather
        // than first: a phone's room holds it and a run at about half its
        // ceiling, and that is a better page than cards alone. Only where the
        // run would be smaller than it is worth drawing at do the cards take
        // the whole room.
        let heads = most.heads && spare >= least

        // AND THE TWO LINES AT THE FOOT go after both, being what a reader
        // reads once they have found the cards. They cost the run their own
        // height, so they stand only where it can spare it AND still reach its
        // ceiling - a page that had to shrink the cards has nothing to add at
        // the bottom.
        let foots = most.foots && heads && spare - gap - footer >= gallery

        return (foots ? .full : (heads ? .heading : .cards),
                // The run takes what is left, up to its own ceiling.
                max(min(heads ? spare : usable - words, gallery), least))
    }

    /// How long the measurement has to hold still before the page takes it
    /// as settled, in milliseconds on the cycle's own clock.
    private static var steady: Double { 240 }

    /// How long it is worth waiting for a measurement at all, in milliseconds
    /// - past which the page simply arrives, an entrance being worth less than
    /// a page nobody can see.
    private static var patience: Double { 1500 }

    /// How long the page takes to come in, in milliseconds.
    private static var entrance: UInt { 700 }

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
