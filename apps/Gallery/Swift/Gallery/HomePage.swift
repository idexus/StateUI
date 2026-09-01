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

    /// How tall the CELL the cards stand in is - read off an empty box lying
    /// behind them, whose frame is the cell's own and echoes nothing about
    /// what else stands there. It steers ONE thing: whether the two lines at
    /// the foot still earn their row.
    @State private var cell = 0.0

    /// Whether the two lines at the foot are shown. Written by the measurement
    /// below rather than read from it, so the answer cannot flutter on the
    /// boundary: the room the lines free by going is smaller than the gap
    /// between the two thresholds.
    @State private var foot = true

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

        // A GRID OF THREE ROWS: the heading takes what it needs, the run of
        // cards takes what is LEFT, and the two lines about what this is sit
        // at the foot. Nothing here is measured to make that true - the rows
        // are the arithmetic.
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
            .isVisible(headerShows)
            .gridRow(0)

            // THE RUN AND THE WORDS UNDER IT, one pair, CENTRED in whatever
            // the heading and the foot leave. The words are always right under
            // the cards' box, and the box is fitted - up to a run's own
            // ceiling - to exactly the room this page can give the pair.
            //
            // The room is read off an invisible box lying BEHIND the pair,
            // whose frame is the star row's own and follows from nothing the
            // pair does: the star row is what the other rows leave. Measuring
            // anything whose size answers back is a measure that feeds itself,
            // and it hangs the process - measured, twice.
            BoxView(Color("#00000000"))
                .inputTransparent(true)
                .verticalOptions(.fill)
                .horizontalOptions(.fill)
                .onFrameChanged { frame in
                    guard abs(frame.height - cell) > 1 else { return }

                    cell = frame.height

                    // THE FOOT GOES BEFORE THE CARDS START SHRINKING, which is
                    // the one moment worth naming: while the cell can still
                    // hold a full-size run plus its words, the page has room to
                    // spare and the lines belong on it; the moment it cannot,
                    // they are what the run takes the room from.
                    if foot, cell < Self.shrinks + Self.footer { foot = false }
                    if !foot, cell > Self.shrinks + 2 * Self.footer + 20 { foot = true }
                }
                .gridRow(1)

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

                // WHAT THE CARD IN THE MIDDLE IS. Under the run rather than on
                // it: a card carries a name, and everything else about a group
                // is a sentence that would not fit on one.
                VStack {
                    Label(group.title)
                        .fontSize(22)
                        .fontAttributes(.bold)
                        .horizontalTextAlignment(.center)

                    Label(group.summary)
                        .fontSize(14)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    Label("\(group.shown(on: device.idiom).count) samples · tap the "
                        + "card to open")
                        .fontSize(12)
                        .textColor(Palette.accent)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
            }
            .spacing(12)
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
            .isVisible(foot && headerShows)
            .gridRow(2)
        }
        .rowDefinitions(.auto, .star, .auto)
        .rowSpacing(14)
        .padding(24)
        .opacity($shown)
        // THE PAGE COMES IN ONCE THE ROOM HAS ANSWERED. Everything here is
        // arranged FROM the measurement below - the cards' box is what the
        // star row can spare - so the first arrangement is a guess and the
        // second is the answer, and the step between them is a jump in the
        // cards and in everything standing under them.
        //
        // On LOADED rather than on the measurement changing: `cell` is written
        // from inside this very Grid, so the render that moves it is the one
        // that rebuilds the watch, and a watch rebuilt is a watch that starts
        // over rather than firing. Waiting for the number here is one line and
        // cannot miss it.
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

    /// How tall the cards' box is: what the star row can give the pair once
    /// the words have theirs, and never more than a run at its ceiling needs -
    /// past that the room is simply room and the pair stands in the middle of
    /// it. The rest looks after itself: a gallery is FITTED to whatever box it
    /// is given.
    private var box: Double {
        // A SIZE IS ASKED FOR FROM THE FIRST RENDER, and it is the ceiling
        // rather than nothing: a run given no height at all leaves the star
        // row free to hand the pair whatever it likes, which the measurement
        // then reads back and asks for again - a measure feeding itself, and
        // the process at a whole core. Measured.
        guard cell > 0 else { return Self.gallery }

        return max(min(cell - Self.words, Self.gallery), Self.least)
    }

    /// The cell that still holds a run of cards at its full size, and the
    /// words under it - the height below which the run starts shrinking, and
    /// therefore the number every threshold on this page is counted from.
    private static var shrinks: Double { gallery + words }

    /// A run of cards at its largest - the gallery's own ceiling.
    private static var gallery: Double { 400 }

    /// The two lines at the foot, their gap included - both what they take out
    /// of the page and what they give it back by going.
    private static var footer: Double { 54 }

    /// What the words under the cards take out of the pair's room, the gap
    /// joining them included.
    private static var words: Double { 106 }

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

                // ONE LINE, whatever the card's width: a caption that wrapped
                // in the small cards would change the picture's height with it.
                Label(group.title)
                    .fontSize(18)
                    .fontAttributes(.bold)
                    .textColor(Palette.onBrand)
                    .lineBreakMode(.tailTruncation)
                    .padding(12, 10)
                    // A dark strip under the words, so a caption reads over a
                    // picture of any colour.
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
