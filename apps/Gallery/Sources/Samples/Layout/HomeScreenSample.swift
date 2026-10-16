import StateUI

/// A home screen of icons: boards side by side, turned a board a swipe.
struct HomeScreenSample: SampleContent, ExampleContent {
    static let id = "homeScreen"
    static let title = "Home screen"
    static let summary = "Boards of icons as many as the room fits - a swipe turns one; a held icon moves the others."

    // listing: HomeScreenSample
    /// One icon: its name, which is its identity, its glyph and its colour.
    struct HomeIcon: Hashable {
        let name: String
        let glyph: Icon
        let colour: String
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
            ("Friends", .person), ("Journal", .edit), ("Timer", .clock), ("Favourites", .star),
            ("Fitness", .heart), ("Videos", .play), ("Wallet", .lock), ("Backup", .upload),
            ("Reader", .info), ("Garden", .home), ("Chat", .mail), ("Agenda", .calendar),
            ("Remote", .settings), ("Shortcuts", .link), ("Albums", .copy), ("Compass", .forward),
        ]
        let colours = ["#7C3AED", "#2563EB", "#0D9488", "#D97706", "#DB2777", "#4F46E5", "#16A34A", "#DC2626"]
        return glyphs.enumerated().map { index, glyph in
            HomeIcon(name: glyph.0, glyph: glyph.1, colour: colours[index % colours.count])
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

    /// The icons, in order.
    @State private var icons = Self.all

    /// Which board is in front - handed on with `$`, never read in the body.
    @State private var board = 0.0

    /// The icon the hand holds, lifted: larger, so the hand knows it has it.
    @State private var lifted: String?

    /// The room the boards stand in, as the host feeds it - no body reads it -
    /// and the grid it fits, which the body reads: a new grid is a new
    /// description, and every icon travels to its new place.
    @State private var room = Rect.zero
    @State private var fit = Fit()
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
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                // THE BOARDS: a unit of the phase is the room's width, so a
                // board is the room however wide it grows.
                LayoutEngine(icons, id: \.name) { icon in
                    tile(icon)
                } placements: { room, board in
                    (0..<count).map { place($0, board, room, fit) }
                }
                .phase($board)
                .input(.pages(.horizontal))
                .snapTargets((0..<boards).map(Double.init))
                // HELD, AN ICON LEAVES ITS BOARD for the hand: each move
                // gives it the slot under the hand, and the others travel to
                // make room; held still at an edge, the boards turn under it.
                // Taken, it lifts, so the hand knows it has it; let go, it
                // settles back.
                .itemDrag(begins: .held)
                .onItemDragged { drag in
                    switch drag.phase {
                    case .began:
                        lifted = drag.item.name
                    case .ended, .cancelled:
                        lifted = nil
                    default:
                        move(drag.item, to: slot(at: drag.at, in: drag.room, fit: fit, of: boards))
                        if drag.still >= .milliseconds(500) { turn(at: drag.at, in: drag.room, of: boards) }
                    }
                }
                .motion(Self.turning)
            }
            .gridRow(0)
            .clipsContent(true)
            // THE GRID THE ROOM FITS: a turned phone or a window grown or
            // shrunk moves icons to other boards, or makes them larger.
            .frame($room)
            .engine(following: $room) { _ in fitted() }

            // THE DOTS wear the same phase - one state, so one motion: they go
            // with the hand and with every throw, no body read of it.
            LayoutEngine(Array(0..<boards)) { _ in
                Rectangle(Palette.text)
                    .cornerRadius(4)
            } placements: { room, board in
                (0..<boards).map { dot($0, of: boards, board, room) }
            }
            .phase($board)
            .motion(Self.turning)
            .height(16)
            .gridRow(1)
        }
        .rows(.fill, .auto)
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

    /// The slot under `point` of the board in front, of `boards` in `fit`.
    private func slot(at point: Point, in room: Rect, fit: Fit, of boards: Int) -> Int {
        let page = min(max(Int(board.rounded()), 0), boards - 1)
        let column = min(max(Int((point.x - 8) / ((room.width - 16) / Double(fit.columns))), 0), fit.columns - 1)
        let row = min(max(Int((point.y - 8) / ((room.height - 16) / Double(fit.rows))), 0), fit.rows - 1)
        return min(page * fit.perBoard + row * fit.columns + column, icons.count - 1)
    }

    /// `icon` taken out of its place and put at `slot`: a new order, which
    /// the others travel to.
    private func move(_ icon: HomeIcon, to slot: Int) {
        guard let from = icons.firstIndex(of: icon), from != slot else { return }
        icons.remove(at: from)
        icons.insert(icon, at: slot)
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
    private func place(_ slot: Int, _ board: Double, _ room: Rect, _ fit: Fit) -> Placement {
        let (page, cell) = slot.quotientAndRemainder(dividingBy: fit.perBoard)
        let width = (room.width - 16) / Double(fit.columns)
        let height = (room.height - 16) / Double(fit.rows)

        return Placement(
            Rect((Double(page) - board) * room.width + 8 + Double(cell % fit.columns) * width,
                 8 + Double(cell / fit.columns) * height, width, height),
            transform: .scale(min(width / 84, height / 96)))
    }

    /// Where the dot of `page` stands under the boards: lit as its board comes
    /// in front.
    private func dot(_ page: Int, of pages: Int, _ board: Double, _ room: Rect) -> Placement {
        let x = room.width / 2 + (Double(page) - Double(pages - 1) / 2) * 16

        return Placement(
            Rect(x - 4, room.height / 2 - 4, 8, 8),
            opacity: 0.25 + 0.75 * max(1 - abs(board - Double(page)), 0))
    }

    /// One icon: its glyph on a light disc on a rounded square of its colour -
    /// the glyph in the platform's own colour, which shows on the disc in a
    /// light theme and a dark one alike - and its name under it.
    private func tile(_ icon: HomeIcon) -> some View {
        VStack {
            ZStack {
                Rectangle(Color(icon.colour))
                    .cornerRadius(14)

                Rectangle(.white)
                    .cornerRadius(21)
                    .opacity(0.3)
                    .width(42)
                    .height(42)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)

                Image(.icon(icon.glyph))
                    .width(26)
                    .height(26)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .width(60)
            .height(60)
            .horizontalAlignment(.center)

            Text(icon.name)
                .fontSize(12)
                .horizontalAlignment(.center)
        }
        .spacing(6)
        .verticalAlignment(.center)
        // Lifted while the hand holds it, on a spring of its own that goes a
        // little past and back.
        .scale(lifted == icon.name ? 1.18 : 1)
        .motion(.spring(response: .milliseconds(260), damping: 0.55), .transform)
    }
    // listing: end

    var notes: (any View)? {
        Text("Swipe the boards either way - one board a swipe, however far your hand goes. "
            + "Hold an icon until it lifts, then move it: the others make room. Hold it at an edge to turn the board. "
            + "Turn the phone or resize the window: the boards hold as many icons as fit, six by six at most.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
