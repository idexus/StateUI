import StateUI

/// A home screen of icons: boards side by side, turned a board a swipe.
struct HomeScreenSample: SampleContent, ExampleContent {
    static let id = "homeScreen"
    static let title = "Home screen"
    static let summary = "Boards of icons side by side - a swipe turns one; a held icon moves and the others make room."

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
        ]
        let colours = ["#7C3AED", "#2563EB", "#0D9488", "#D97706", "#DB2777", "#4F46E5", "#16A34A", "#DC2626"]
        return glyphs.enumerated().map { index, glyph in
            HomeIcon(name: glyph.0, glyph: glyph.1, colour: colours[index % colours.count])
        }
    }()

    /// How many icons stand across a board and down it.
    static let columns = 4
    static let rows = 5

    /// How the boards turn - and the dots with them: one state, one motion.
    static let turning = Motion.spring(response: .milliseconds(380), damping: 0.86)

    /// The icons, in order.
    @State private var icons = Self.all

    /// Which board is in front - handed on with `$`, never read in the body.
    @State private var board = 0.0

    /// The icon the hand holds, lifted: larger, so the hand knows it has it.
    @State private var lifted: String?
    // listing: end

    // The boards are turned by the hand of their own, so the example is not
    // put in a second scroller.
    static let scrolls = false

    // And it takes the whole cell: a board is the room.
    static let fills = true

    // listing: HomeScreenSample
    var body: some View {
        let count = icons.count
        let boards = (count + Self.columns * Self.rows - 1) / (Self.columns * Self.rows)

        return Grid {
            Grid {
                Rectangle(Palette.raised)
                    .cornerRadius(14)

                // THE BOARDS: a unit of the phase is the room's width, so a
                // board is the room however wide it grows.
                LayoutEngine(icons, id: \.name) { icon in
                    tile(icon)
                } placements: { room, board in
                    (0..<count).map { place($0, board, room) }
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
                        move(drag.item, to: slot(at: drag.at, in: drag.room, of: boards))
                        if drag.still >= .milliseconds(500) { turn(at: drag.at, in: drag.room, of: boards) }
                    }
                }
                .motion(Self.turning)
            }
            .gridRow(0)
            .clipsContent(true)

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

    /// The slot under `point` of the board in front, of `boards`.
    private func slot(at point: Point, in room: Rect, of boards: Int) -> Int {
        let page = min(max(Int(board.rounded()), 0), boards - 1)
        let column = min(max(Int((point.x - 8) / ((room.width - 16) / Double(Self.columns))), 0), Self.columns - 1)
        let row = min(max(Int((point.y - 8) / ((room.height - 16) / Double(Self.rows))), 0), Self.rows - 1)
        return min(page * Self.columns * Self.rows + row * Self.columns + column, icons.count - 1)
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

    /// Where the icon at `slot` stands: on its board, in its row and column,
    /// the boards side by side a room's width apart.
    private func place(_ slot: Int, _ board: Double, _ room: Rect) -> Placement {
        let (page, cell) = slot.quotientAndRemainder(dividingBy: Self.columns * Self.rows)
        let width = (room.width - 16) / Double(Self.columns)
        let height = (room.height - 16) / Double(Self.rows)

        return Placement(
            Rect((Double(page) - board) * room.width + 8 + Double(cell % Self.columns) * width,
                 8 + Double(cell / Self.columns) * height, width, height),
            transform: .scale(min(width / 84, height / 96, 1)))
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
            + "Hold an icon until it lifts, then move it: the others make room. Hold it at an edge to turn the board.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
