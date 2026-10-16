// listing: AppSwitcherSample
import StateUIFoundation
// listing: end
import StateUI

/// An app switcher: cards scrolled sideways, a card pulled up flies off and
/// the others close up.
struct AppSwitcherSample: SampleContent, ExampleContent {
    static let id = "appSwitcher"
    static let title = "App switcher"
    static let summary = "A phone's app switcher - scroll the cards; one pulled up and let go high or fast closes."

    // listing: AppSwitcherSample
    /// One running app: its name, which is its identity, and its picture -
    /// one of the gallery's groups' cards, as its home page shows them.
    struct RunningApp: Hashable {
        let name: String
        let art: String
    }

    /// Every app the switcher starts with.
    static let all = [
        RunningApp(name: "Fundamentals", art: "cat_fundamentals.png"),
        RunningApp(name: "Driven values", art: "cat_driven.png"),
        RunningApp(name: "Using state", art: "cat_state.png"),
        RunningApp(name: "Animation", art: "cat_animation.png"),
        RunningApp(name: "Controls", art: "cat_basicinput.png"),
        RunningApp(name: "Text & typing", art: "cat_text.png"),
        RunningApp(name: "Layout", art: "cat_layout.png"),
        RunningApp(name: "Styles", art: "cat_styles.png"),
        RunningApp(name: "Shapes", art: "cat_shapes.png"),
        RunningApp(name: "Gestures", art: "cat_gestures.png"),
    ]

    /// The apps still running, in order.
    @State private var apps = Self.all

    /// Which card is in front - the third, two older apps under it to the
    /// left - handed on with `$`, never read in the body.
    @State private var turn = 2.0
    // listing: end

    // The cards are moved by the hand of their own, so the example is not put
    // in a second scroller.
    static let scrolls = false

    // And it takes the whole cell: the cards want the room.
    static let fills = true

    // listing: AppSwitcherSample
    var body: some View {
        let (count, running) = (apps.count, apps)

        return Grid {
            Grid {
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                LayoutEngine(running, id: \.name) { app in
                    AppCard(app: app, index: running.firstIndex(of: app) ?? 0, turn: $turn)
                } placements: { room, turn in
                    (0..<count).map { place($0, turn, room) }
                }
                .phase($turn)
                // Thrown as the gallery's home turns its cards: a spring that
                // carries the hand on and settles.
                .input(.scroll(.horizontal, throwing: .spring(response: .milliseconds(500), damping: 0.8)))
                .snapTargets(running.indices.map(Double.init))
                // A FIRST MOVE UP is the card's: it follows the hand; let go
                // high or fast, it flies off and the app closes - the others
                // close up, the card in front staying in front.
                .itemDrag(begins: .across)
                .onItemDismissed(.up, beyond: 120) { app in close(app) }
            }
            .gridRow(0)
            .clipsContent(true)

            Button("Open all again").onClicked {
                apps = Self.all
                $turn.journey.snap(to: 2)
            }
            .horizontalAlignment(.center)
            .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }

    /// `app` closed: the others close up; one before the card in front keeps
    /// that card in front, and where the last closes, the phase travels to
    /// the one before.
    private func close(_ app: RunningApp) {
        guard let leaving = apps.firstIndex(of: app) else { return }
        let front = min(max(Int(turn.rounded()), 0), apps.count - 1)
        apps.remove(at: leaving)
        if leaving < front {
            $turn.journey.snap(to: Double(front - 1))
        } else if front > apps.count - 1 {
            $turn.journey.move(to: Double(max(apps.count - 1, 0)))
        }
    }

    /// A card's size in `room`, and where its left edge stands `step` from
    /// the one in front: the next one over it to the right, a card apart;
    /// those before it nearer the room's left edge the farther under they
    /// go, and never past it.
    private func across(_ step: Double, in room: Rect) -> (width: Double, height: Double, left: Double) {
        // A card is its picture's shape, 400 by 560, under its icon's row.
        let width = min((room.height - 36 - 36) * 400 / 560, room.width * 0.66)
        let height = width * 560 / 400 + 36
        let middle = room.width / 2 - width / 2
        let behind = max(-step, 0)
        let edge = 0.0
        let left = step >= 0 ? middle + step * width * 0.84
            : edge + (middle - edge) * exp(-0.8 * behind)
        return (width, height, left)
    }

    /// Where the card at `index` stands, as a phone's switcher stands them,
    /// each later one over the one before, those under the front one a
    /// little smaller.
    private func place(_ index: Int, _ turn: Double, _ room: Rect) -> Placement {
        let step = Double(index) - turn
        let (width, height, left) = across(step, in: room)
        let behind = max(-step, 0)

        return Placement(
            Rect(left, (room.height - height) / 2, width, height),
            transform: .scale(1 - min(behind, 3) * 0.04),
            opacity: min(max(1.6 - behind * 0.6, 0), 1) * min(max(3 - step, 0), 1),
            zIndex: index)
    }

    /// One card: its icon and name over its window - its picture, cut to the
    /// card's corners; the icon is the same picture, small. Its name fades
    /// as the card goes under the one in front: a state of the card's own,
    /// which an engine following the phase writes where the run is shown -
    /// the hand's place too - and the name's opacity wears.
    struct AppCard: View {
        let app: RunningApp
        let index: Int
        let turn: Binding<Double>

        @State private var named = 1.0

        var body: some View {
            Grid {
                HStack {
                    ZStack { Image(ImageSource(app.art)).contentMode(.fill) }
                        .shape(.roundedRectangle(7))
                        .clipsContent(true)
                        .width(28)
                        .height(28)
                    Text(app.name)
                        .fontSize(17)
                        .fontWeight(.semibold)
                        .textColor(Palette.onBrand)
                        .lineBreak(.tailTruncation)
                        .opacity($named)
                }
                .spacing(10)
                .gridRow(0)

                ZStack { Image(ImageSource(app.art)).contentMode(.fill) }
                    .shape(.roundedRectangle(26))
                    .clipsContent(true)
                    .gridRow(1)
            }
            .rows(.auto, .fill)
            .rowSpacing(8)
            .engine(following: turn) { _ in
                named = min(max(1 + (Double(index) - turn.journey.value) / 0.6, 0), 1)
            }
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Scroll the cards sideways. Pull one up and let go high, or flick it, to close the app; "
            + "short of that it goes back.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
