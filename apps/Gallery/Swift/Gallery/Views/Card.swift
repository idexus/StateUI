// One tappable row: a title, a line about it, and where it goes.

import StateUI

/// The gallery's one navigational shape - a card on the home page, a row on a
/// group's page.
///
/// The WHOLE card answers a tap, which is what a row of a list is in MAUI: a
/// view with a `TapGestureRecognizer` on it, not a button with something around
/// it. The chevron is a chevron - it says where the row goes and nothing more.
/// And because a tapped Border shows nothing where a Button would, the card
/// says the press back itself: a quick dip in scale before the action runs.
///
/// A FILL and a hairline, which is what makes it read as raised on the tinted
/// page behind it - see `Palette.surface`. Both come from the implicit
/// `Style<Border>`, so nothing here says what a card looks like.
///
/// It is shaped the way every control in the library is, and that shape is the
/// rule for a composed view of your own: WHAT IT IS goes in the initializer -
/// with no default, so leaving it out is not a thing that can happen - and
/// everything a caller may leave out is a MODIFIER returning `Self`, one copy
/// and one assignment, exactly as `CollectionView.itemSize` is written.
///
/// Its own modifiers are written FIRST, before the ones every view has:
/// `.margin` and friends give back a `ModifiedContent`, which is a view and no
/// longer a `Card`.
struct Card: ContentView {
    private let title: String
    private let summary: String
    private let action: EventHandler

    /// A file in Resources/Images, or empty for no icon.
    private var picture: ImageSource = ""

    /// How big the card is drawn, and what the press moves. DRIVEN: the host
    /// carries the scale on its own frames and no render describes it, so a
    /// press costs the arithmetic and nothing else.
    ///
    /// Per INSTANCE, the way state on a view is - every card on every page
    /// holds its own, so there is no name to compose and nothing to collide.
    @State(asks: .never) private var dip = AnimatedValue(1.0)

    /// - Parameters:
    ///   - title: What the row is called.
    ///   - summary: The line under it.
    ///   - action: Run when the card is tapped. May await - tapping a card
    ///     navigates, and where it goes is what a card IS.
    init(_ title: String, summary: String, action: @escaping EventHandler) {
        self.title = title
        self.summary = summary
        self.action = action
    }

    /// The picture at the head of the card - a file in Resources/Images. A
    /// card that names none draws none, and the words start at the edge.
    func icon(_ value: ImageSource) -> Self {
        var copy = self
        copy.picture = value
        return copy
    }

    /// `ContentView`, not `Element`: the press is a piece of `@State` now, and
    /// state on a view needs the placeholder a composed view puts in the tree.
    /// The differ builds the content once it knows this card stood here last
    /// render, and hands the rebuilt `dip` the storage its predecessor held;
    /// an eager `body` would hand out a fresh 1.0 on every render and the dip
    /// would have nowhere to live.
    var content: Element {
        // Copies for the handler to capture - and NOT a capture list, which
        // looks equivalent and is not: a closure with an explicit capture
        // list, written in a content getter, is moved off this library's
        // executor by the compiler (Swift 6.3) - the host sees no job and no
        // pending resume, and the press froze until the NEXT event reached
        // the app; on Android it would never resume at all. The locals keep
        // `self` out of the closure, and a BINDING is copied for that exactly
        // as a handle was. Measured both ways; ConcurrencyTests pins this
        // shape.
        let dip = $dip
        let action = self.action

        return Border {
            Grid {
                Image(picture)
                    .widthRequest(24)
                    .heightRequest(24)
                    .isVisible(!picture.isEmpty)
                    .verticalOptions(.center)

                VStack {
                    Label(title)
                        .fontSize(17)
                        .fontAttributes(.bold)

                    Label(summary)
                        .fontSize(13)
                        .textColor(Palette.subtle)
                        .maxLines(2)
                }
                .gridColumn(1)
                .spacing(2)
                .horizontalOptions(.fill)
                .verticalOptions(.center)

                Label("›")
                    .gridColumn(2)
                    .fontSize(22)
                    .textColor(Palette.accent)
                    .verticalOptions(.center)
            }
            .columnSpacing(14)
            // The TEXT is the star column. An Auto column measures a Label at
            // the width it would like - the whole summary on one line - so the
            // text ran under the chevron and out through the border, with an
            // empty star column beside it holding the space it needed. A star
            // column is given what the others left, and a Label given a width
            // wraps to it.
            .columnDefinitions(.auto, .star, .auto)
            .padding(16, 14)
        }
        .scale($dip)
        // The press, said back: a Border with a TapGestureRecognizer draws
        // nothing on its own, unlike a Button, so without this a tap shows
        // nothing until the page changes. The DIP runs to the end before the
        // action starts - it is the feedback, and a navigation's page build
        // freezes the UI thread, which eats every animation frame beside it:
        // with the action started at once there was no press to see at all.
        // The dip reaches the control on the host's own next frame, which is
        // sooner than any act, so that order stands.
        //
        // The RETURN rides the navigation (`async let`, awaited before the
        // handler ends): the frames the build eats are frames nobody sees
        // anyway - the screen holds still - and the transition draws the rest,
        // the card leaving restored. Sequential works too and costs 30ms more
        // before the page moves. The card ends at 1 either way, and it is the
        // STATE that says so: `animateTo` writes its target into `dip` the
        // moment it starts, so the card stands at full size whether the walk
        // was ever drawn or not - and a return whose card has already left
        // with the page reaches no control and lands on the spot. Nothing has
        // to put anything back afterwards.
        .onTapped {
            try await dip.animateTo(0.96, .eased(50, .cubicOut))
            async let restored: Bool = dip.animateTo(1, .eased(30, .cubicOut))
            try await action()
            _ = try await restored
        }
    }
}
