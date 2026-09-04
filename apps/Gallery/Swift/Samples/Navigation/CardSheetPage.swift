import StateUI

/// A bottom sheet the GALLERY draws, over a modal page that shows through.
///
/// The platform gives one modal presentation everywhere - a page over the whole
/// window - and a CHOICE of sheet styles on iOS and Mac Catalyst alone. This is
/// the other answer, and it is the one that looks the same on all four
/// platforms: present a page that covers the screen WITHOUT taking away what is
/// under it (`.overFullScreen`), paint it transparent, and put the sheet in it
/// as ordinary views.
///
/// Nothing here is a platform feature. The sheet is TWO DRIVEN STATES this page
/// owns - how dark the backdrop is drawn, and how far below its place the card
/// sits - each read by the view that shows it and each sent from `.onLoaded`,
/// MAUI's `VisualElement.Loaded`, which is raised as a view attaches. That is
/// the hook an entrance hangs off: the handler that presented the page ran
/// before any of these views existed, so the movement belongs to the views.
///
/// The whole entrance and the whole exit cost NO RENDERS: the host reads both
/// numbers off the image on its own frames.
struct CardSheetPage: ContentPage {
    let nav: Navigation

    /// The page under this one is LEFT IN PLACE, which is what makes a
    /// transparent background worth having. Apple only; Android and Windows
    /// present it over the window anyway, which is the same picture arrived at
    /// from the other side.
    var modalPresentationStyle: UIModalPresentationStyle? { .overFullScreen }

    /// Nothing of its own, so what shows through is whatever the backdrop
    /// leaves - see the `BoxView` below, which IS the dimming.
    var backgroundColor: Color? { .transparent }

    /// How far below its place the card starts, and where it goes back to, in
    /// MAUI units. Bigger than the card is tall, so it begins off the bottom of
    /// the screen whatever the text inside it comes to.
    private static let travel = 420.0

    /// How dark the backdrop is drawn: nothing to begin with, 0.45 while the
    /// sheet is up.
    @Bus private var shade = AnimatedValue(0.0)

    /// How far below its place the card sits: a full `travel` to begin with,
    /// zero when it is home.
    @Bus private var drop = AnimatedValue(Self.travel)

    var content: Element {
        Grid {
            // The dimming, and the way out that every sheet has: a tap beside
            // the card. It sends ITSELF in - one movement per view, each
            // started where that view attaches, so neither waits for the other.
            BoxView()
                .color(Color("#000000"))
                .opacity($shade)
                .onTapped { await close() }
                .onLoaded { _ = try? await $shade.animateTo(0.45, .eased(220)) }

            VStack {
                // The grab handle a sheet has on every platform that draws one
                // - here it is four points of rounded box, because that is all
                // it ever was.
                BoxView()
                    .color(Palette.subtle)
                    .widthRequest(40)
                    .heightRequest(4)
                    .cornerRadius(2)
                    .horizontalOptions(.center)

                Label("A sheet with nothing platform-specific in it")
                    .fontSize(18)
                    .fontAttributes(.bold)
                    .horizontalTextAlignment(.center)

                Label("A modal page presented `.overFullScreen`, painted transparent, "
                    + "with these views inside it. Two pieces of state move: how dark "
                    + "the backdrop is, and how far down the card sits. Both are sent "
                    + "from `.onLoaded` and sent back before the array is shortened, so "
                    + "the same movement happens on iOS, Android, Mac and Windows - and "
                    + "none of it is described, so none of it costs a render.")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)

                Button("Close")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { await close() }
            }
            .spacing(14)
            .padding(24, 20, 24, 34)
            .backgroundColor(Palette.surface)
            .verticalOptions(.end)
            .translationY($drop)
            .onLoaded { _ = try? await $drop.animateTo(0, .eased(260, .cubicOut)) }
        }
    }

    /// Sends the card back down, THEN takes it off the array.
    ///
    /// The order is the whole trick, and it is the one thing a hand-drawn sheet
    /// has to get right: shortening the array first would take the page away and
    /// leave nothing to move. `drop.setPoint` holding `travel` again from the
    /// moment the movement starts does not soften that - what actually moves is
    /// the control, and the control is only there to move while the array still
    /// names this page.
    private func close() async {
        // The two bindings first, as LOCALS: `async let` starts a child task,
        // and one that reached for `self` would be carrying this page's
        // `Navigation` - a pair of bindings, which is not Sendable and is
        // refused. So each movement is handed exactly the one piece of state
        // it moves and nothing else.
        let sinking = $drop
        let dimming = $shade

        async let sunk: Bool = sinking.animateTo(Self.travel, .eased(200, .cubicIn))
        async let faded: Bool = dimming.animateTo(0, .eased(200))

        _ = try? await sunk
        _ = try? await faded

        nav.dismiss()
    }
}
