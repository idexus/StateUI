import StateUI

/// A home screen of icons: boards side by side, turned a board a swipe.
struct HomeScreenSample: SampleContent, ExampleContent {
    static let id = "homeScreen"
    static let title = "Home screen"
    static let summary = "Boards of icons: a swipe turns one, a held icon moves the others, a pressed one opens its app."

    // listing: HomeScreenSample
    /// One icon: its name, which is its identity, its glyph and its color.
    struct HomeIcon: Hashable {
        let name: String
        let glyph: Icon
        let color: Color
    }

    /// Every icon, board after board: where one stands in the order is where
    /// it stands on the screen.
    static let all: [HomeIcon] = {
        let glyphs: [(String, Icon)] = [
            ("Mail", .mail), ("Calendar", .calendar), ("Clock", .clock), ("Photos", .star),
            ("Music", .play), ("Contacts", .person), ("Settings", .settings), ("Health", .heart),
            ("Home", .home), ("Files", .copy), ("Notes", .edit), ("Search", .search),
            ("Share", .share), ("Cloud", .upload), ("Store", .download), ("Links", .link),
            ("Vault", .lock), ("Tips", .info), ("Alerts", .warning), ("Podcasts", .pause),
            ("Sync", .refresh), ("Tasks", .checkmark), ("Menu", .menu), ("More", .more),
            ("Map", .forward), ("News", .add), ("Books", .back), ("Weather", .up),
            ("Trash", .delete), ("Inbox", .down), ("Focus", .close), ("Budget", .remove),
            ("Friends", .person), ("Journal", .edit), ("Timer", .clock), ("Favorites", .star),
            ("Fitness", .heart), ("Videos", .play), ("Wallet", .lock), ("Backup", .upload),
            ("Reader", .info), ("Garden", .home), ("Chat", .mail), ("Agenda", .calendar),
            ("Remote", .settings), ("Shortcuts", .link), ("Albums", .copy), ("Compass", .forward),
        ]
        let colors: [Color] = [
            Color(hex: 0x7C3AED), Color(hex: 0x2563EB), Color(hex: 0x0D9488), Color(hex: 0xD97706),
            Color(hex: 0xDB2777), Color(hex: 0x4F46E5), Color(hex: 0x16A34A), Color(hex: 0xDC2626),
        ]
        return glyphs.enumerated().map { index, glyph in
            HomeIcon(name: glyph.0, glyph: glyph.1, color: colors[index % colors.count])
        }
    }()

    /// How many icons stand across a board and down it: as many as fit the
    /// room at an icon's own size - 84 by 96 - six at most each way.
    struct Fit: Equatable {
        var columns = 4
        var rows = 5

        var perBoard: Int { columns * rows }

        /// The fit of `room`.
        static func of(_ room: Rect) -> Fit {
            guard room.width > 0, room.height > 0 else { return Fit() }
            return Fit(columns: min(max(Int((room.width - 16) / 84), 1), 6),
                       rows: min(max(Int((room.height - 16) / 96), 1), 6))
        }

        /// The board of this grid that shows most of the icons `page` of
        /// `before` showed - the first of two that show as many - of `count`:
        /// a turned phone keeps its place among the icons.
        func board(showing page: Int, of before: Fit, count: Int) -> Int {
            let shown = page * before.perBoard ..< min((page + 1) * before.perBoard, count)
            var best = (board: 0, icons: 0)
            for board in 0..<max((count + perBoard - 1) / perBoard, 1) {
                let here = board * perBoard ..< min((board + 1) * perBoard, count)
                let icons = shown.clamped(to: here).count
                if icons > best.icons { best = (board, icons) }
            }
            return best.board
        }
    }

    /// How the boards turn - and the dots with them: one state, one motion.
    static let turning = Motion.spring(response: .milliseconds(380), damping: 0.86)

    /// How an icon grows into its app, and how the app closes onto the icon.
    static let opening = Motion.spring(response: .milliseconds(320), damping: 0.88)
    static let closing = Motion.spring(response: .milliseconds(280), damping: 0.9)

    /// How the words on an app come in: slowly, then all at once; and how the
    /// app follows the hand pulling it - a short spring a step behind, still
    /// moving at the hand's speed as the hand lets go, so the close goes on
    /// from there.
    static let late = Motion.eased(.milliseconds(300), curve: .cubicIn)
    static let following = Motion.spring(response: .milliseconds(80), damping: 1)

    /// The icons, in order.
    @State private var icons = Self.all

    /// Which board is in front - handed on with `$`, never read in the body.
    @State(motion: Self.turning) private var board = 0.0

    /// The icon the hand holds, lifted: larger, so the hand knows it has it.
    @State private var lifted: String?

    /// The room the boards stand in, as the host feeds it - no body reads it -
    /// and the grid it fits, which the body reads: a new grid is a new
    /// description, and every icon travels to its new place.
    @State private var room = Rect.zero
    @State private var fit = Fit()

    /// The icon whose app is open, by its name.
    @State private var opened: String?
    // listing: end

    // The boards are turned by the hand of their own, so the example is not
    // put in a second scroller.
    static let scrolls = false

    // And it takes the whole cell: a board is the room.
    static let fills = true

    // listing: HomeScreenSample
    var body: some View {
        let (count, fit) = (icons.count, self.fit)
        let boards = max((count + fit.perBoard - 1) / fit.perBoard, 1)

        return Grid {
            Grid {
                // THE BOARDS: a unit of the parameters is the room's width, so a
                // board is the room however wide it grows. Each board is a
                // keyframe: the icons are placed once a board, and between
                // two they go straight - as the arithmetic says they do.
                MotionLayout(icons, id: \.name, parameters: $board) { icon in
                    // A VIEW OF ITS OWN: a new order builds no icon again,
                    // only the one lifted or let go, opened or closed.
                    HomeTile(icon: icon, lifted: lifted == icon.name, open: opened == icon.name, opened: $opened)
                } placements: { context, board in
                    (0..<count).map { Self.place($0, board, context.bounds, fit) }
                }
                // A BOARD A KEYFRAME: the arithmetic is asked at whole boards,
                // and the icons are blended between them.
                .axis(range: 0...Double(boards - 1), keyframes: .every(1))
                // A PAGE A HAND: the room's width turns one board, the next
                // at most, however far or fast the hand goes.
                .interaction(
                    .value($board, input: .swipe(.horizontal, unit: .containerLength))
                        .reversed(true)
                        .range(0...Double(boards - 1))
                        .snaps(.every(1))
                        .release(.projected(.eased(.milliseconds(400)))))
                // HELD, AN ICON LEAVES ITS BOARD for the hand - each icon
                // says so itself, below: each move gives it the slot under
                // the hand, and the others travel to make room; held still at
                // an edge, the boards turn under it. Taken, it lifts, so the
                // hand knows it has it; let go, it settles back.
                .onItemDragged { drag in
                    switch drag.phase {
                    case .began:
                        lifted = drag.id
                    case .ended, .cancelled:
                        lifted = nil
                    default:
                        // The icon under the hand gives the held one its place.
                        if let over = drag.over, let place = icons.firstIndex(where: { $0.name == over }) { move(drag.id, to: place) }
                        // At an edge, standing there or pushed against it fast, the board turns.
                        if drag.still >= .milliseconds(500) || Self.pushes(drag) {
                            turn(at: drag.at, in: drag.room, of: boards)
                        }
                    }
                }
            }
            .gridRow(0)
            .clipsContent(true)
            // THE GRID THE ROOM FITS: a turned phone or a window grown or
            // shrunk moves icons to other boards, or makes them larger.
            .frame(into: $room)
            .engine(following: $room) { _ in fitted() }

            // THE DOTS wear the same parameters - one state, so one motion: they go
            // with the hand and with every throw, no body read of it.
            MotionLayout(Array(0..<boards), parameters: $board) { _ in
                Rectangle()
                    .fill(Palette.text)
                    .cornerRadius(4)
            } placements: { context, board in
                (0..<boards).map { dot($0, of: boards, board, context.bounds) }
            }
            .height(16)
            .gridRow(1)

            // AN ICON OPENED: its app over the boards and their dots, grown out
            // of the icon - and closed, by `opened = nil`, back onto it.
            if let icon = icons.first(where: { $0.name == opened }) {
                HomeApp(icon: icon, opened: $opened)
                    .gridRow(0)
                    .gridRowSpan(2)
            }
        }
        .rows(.fill, .automatic)
        .rowSpacing(8)
    }

    /// The grid the room fits now, written where it changed - the board in
    /// front the one that shows most of what it showed, at once, as the
    /// icons travel to their new places.
    private func fitted() {
        let now = Fit.of(room)
        guard now != fit else { return }
        let showing = now.board(showing: Int(board.rounded()), of: fit, count: icons.count)
        fit = now
        if Double(showing) != board { $board.journey.snap(to: Double(showing)) }
    }

    /// The icon `name` taken out of its place and put at `slot`: a new order, which
    /// the others travel to.
    private func move(_ name: String, to slot: Int) {
        guard let from = icons.firstIndex(where: { $0.name == name }), from != slot else { return }
        icons.insert(icons.remove(at: from), at: slot)
    }

    /// Whether the hand reached the edge it stands at going that way faster
    /// than 600 points a second.
    private static func pushes(_ drag: ItemDrag<String>) -> Bool {
        drag.at.x > drag.room.width - 24 && drag.velocity.x > 600 || drag.at.x < 24 && drag.velocity.x < -600
    }

    /// The board on the side of the room `point` stands at the edge of, if
    /// there is one that way.
    private func turn(at point: Point, in room: Rect, of boards: Int) {
        let page = Int(board.rounded())
        if point.x > room.width - 24, page < boards - 1 { $board.journey.move(to: Double(page + 1)) }
        if point.x < 24, page > 0 { $board.journey.move(to: Double(page - 1)) }
    }

    /// Where the icon at `slot` stands: on its board, in its row and column
    /// of `fit`, the boards side by side a room's width apart - larger where
    /// the room gives a cell more than an icon's own size.
    static func place(_ slot: Int, _ board: Double, _ room: Rect, _ fit: Fit) -> Placement {
        // The icon at its own size in the middle of its cell, made larger
        // about its middle as far as the cell lets it: drawn, it covers its
        // own cell and no other, so a press takes the icon under it.
        Placement(cell(slot, board, room, fit), transform: .scale(enlarged(room, fit)))
    }

    /// The icon at `slot` at its own size, in the middle of its cell.
    static func cell(_ slot: Int, _ board: Double, _ room: Rect, _ fit: Fit) -> Rect {
        let (page, cell) = slot.quotientAndRemainder(dividingBy: fit.perBoard)
        let width = (room.width - 16) / Double(fit.columns)
        let height = (room.height - 16) / Double(fit.rows)
        let x = (Double(page) - board) * room.width + 8 + Double(cell % fit.columns) * width
        let y = 8 + Double(cell / fit.columns) * height
        return Rect(x: x + (width - 84) / 2, y: y + (height - 96) / 2, width: 84, height: 96)
    }

    /// How much larger than its own size an icon is drawn in `fit`'s cells.
    static func enlarged(_ room: Rect, _ fit: Fit) -> Double {
        min((room.width - 16) / Double(fit.columns) / 84, (room.height - 16) / Double(fit.rows) / 96)
    }

    /// Where the dot of `page` stands under the boards: lit as its board comes
    /// in front.
    private func dot(_ page: Int, of pages: Int, _ board: Double, _ room: Rect) -> Placement {
        let x = room.width / 2 + (Double(page) - Double(pages - 1) / 2) * 16

        return Placement(
            Rect(x: x - 4, y: room.height / 2 - 4, width: 8, height: 8),
            opacity: 0.25 + 0.75 * max(1 - abs(board - Double(page)), 0))
    }

    /// How what is on an app's surface comes in: faded in as the app appears.
    static let landing = Transition(enter: .opacity, exit: .identity).initialAppearance(true)

    /// An icon's app, over the boards: it grows out of the icon's square and
    /// closes back onto it, its words on it - they come in as it lands; pulled
    /// up by the bar at its foot, or pressed there, it closes.
    struct HomeApp: View {
        let icon: HomeIcon
        @Binding var opened: String?

        /// Where the hand draws the app: moved, and scaled about its foot -
        /// the same each way. An app opened again stands whole.
        @State(motion: HomeScreenSample.opening) private var x = 0.0
        @State(motion: HomeScreenSample.opening) private var y = 0.0
        @State(motion: HomeScreenSample.opening) private var size = 1.0

        var body: some View {
            ZStack {
                // THE APP, of one id with the icon's square - the icon's name:
                // the two are drawn as one on the way, its words with it, its
                // corner going from the square's to its own as far as it has
                // got.
                ZStack {
                    // THE WORDS come in slowly, then all at once: unseen while
                    // the app is still small.
                    VStack {
                        ZStack {
                            Rectangle()
                                .fill(.white)
                                .cornerRadius(48)
                                .opacity(0.3)
                            Image(.platform(icon.glyph))
                                .width(48)
                                .height(48)
                                .horizontalAlignment(.center)
                                .verticalAlignment(.center)
                        }
                        .width(96)
                        .height(96)
                        .horizontalAlignment(.center)

                        Text(icon.name)
                            .fontSize(24)
                            .fontWeight(.semibold)
                            .textColor(.white)
                            .horizontalAlignment(.center)
                    }
                    .spacing(12)
                    .verticalAlignment(.center)
                    .transition(HomeScreenSample.landing)
                    .motion(HomeScreenSample.late)

                    // THE BAR AT ITS FOOT, coming in with the words: held, it
                    // takes the app up with the hand; pressed, it closes the app.
                    ZStack {
                        Rectangle()
                            .fill(.white)
                            .cornerRadius(3)
                            .opacity(0.7)
                            .width(120)
                            .height(6)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .height(40)
                    .verticalAlignment(.end)
                    .transition(HomeScreenSample.landing)
                    .motion(HomeScreenSample.late)
                    .onPanUpdated { pan in pulled(pan) }
                    .onTapped { opened = nil }
                    .accessibilityIdentifier("home.app.bar")
                }
                .background(icon.color)
                .shape(.roundedRectangle(24))
                .transition(id: icon.name)
                .motion(HomeScreenSample.opening)
            }
            // THE APP AS THE HAND DRAWS IT: moved, and scaled about its foot,
            // where the hand holds it. Closed, it goes on from there onto its
            // icon at the speed it had.
            .translationX($x)
            .translationY($y)
            .scaleX($size)
            .scaleY($size)
            .pivotY(1)
            .accessibilityIdentifier("home.app")
        }

        /// The hand on the app's bar: the app follows it, smaller the farther
        /// up; let go high enough, or thrown up, it closes; let go lower, it
        /// goes back.
        private func pulled(_ pan: PanUpdate) {
            switch pan.phase {
            case .began:
                break
            case .changed:
                let lift = min(pan.total.y, 0)
                $x.journey.move(to: pan.total.x, HomeScreenSample.following)
                $y.journey.move(to: lift, HomeScreenSample.following)
                $size.journey.move(to: max(0.4, 1 + lift / 450), HomeScreenSample.following)
            case .ended where pan.total.y < -120 || pan.velocity.y < -800:
                opened = nil
            default:
                (x, y, size) = (0, 0, 1)
            }
        }
    }

    /// One icon: its glyph on a light disc on a rounded square of its color -
    /// the glyph in the platform's own color, which shows on the disc in a
    /// light theme and a dark one alike - and its name under it; larger while
    /// the hand holds it; pressed, its app opens out of it.
    struct HomeTile: View {
        let icon: HomeIcon
        let lifted: Bool
        let open: Bool
        @Binding var opened: String?

        var body: some View {
            VStack {
                if open {
                    // WHILE ITS APP IS OPEN, THE SQUARE IS THE APP'S: its
                    // place here stands empty.
                    Space()
                        .width(60)
                        .height(60)
                        .horizontalAlignment(.center)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.white)
                            .cornerRadius(21)
                            .opacity(0.3)
                            .width(42)
                            .height(42)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)

                        Image(.platform(icon.glyph))
                            .width(26)
                            .height(26)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .background(icon.color)
                    .shape(.roundedRectangle(14))
                    .width(60)
                    .height(60)
                    .horizontalAlignment(.center)
                    // ONE TRANSITION ID WITH ITS APP, the icon's name: the app
                    // grows out of the square and closes onto it, the two
                    // crossing over near the square.
                    .transition(id: icon.name)
                    .motion(HomeScreenSample.closing)
                }

                Text(icon.name)
                    .fontSize(12)
                    .horizontalAlignment(.center)
            }
            .spacing(6)
            .verticalAlignment(.center)
            // Lifted while the hand holds it, on a spring of its own that goes
            // a little past and back.
            .scale(lifted ? 1.18 : 1)
            .motion(.spring(response: .milliseconds(260), damping: 0.55), .transform)
            // THE HAND TAKES THE ICON ITSELF once a press has stood still on
            // it: said here, in the icon's own body, so a new order still
            // builds no icon again.
            .interaction(.drag(.both, begins: .longPress))
            // A PRESS THE HAND DID NOT TAKE OPENS THE ICON'S APP.
            .onTapped { opened = icon.name }
            .accessibilityIdentifier("home.icon.\(icon.name)")
        }
    }

    // listing: end

    var notes: (any View)? {
        Text("Swipe the boards either way - one board a swipe, however far your hand goes. "
            + "Hold an icon until it lifts, then move it over another: the others make room. Hold it at an edge, or "
            + "push it there fast, to turn the board. Press an icon: its app grows out of it; pull the bar at the "
            + "app's foot up, or press it, to close it. "
            + "Turn the phone or resize the window: the boards hold as many icons as fit, six by six at most.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
