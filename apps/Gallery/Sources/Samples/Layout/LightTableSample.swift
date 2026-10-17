import StateUI

/// Photos on a light table: a pan, a pinch and a rotation at once, each
/// driving an axis of one phase.
struct LightTableSample: SampleContent, ExampleContent {
    static let id = "lightTable"
    static let title = "Light table"
    static let summary = "Photos on a light table - pan, pinch and turn them, all at once."

    // listing: LightTableSample
    /// THE PHASE: which photo the table is centred on, across and down, how
    /// near it stands, and how far the photos are turned - a turn a unit.
    struct Table: LayoutPhase {
        var x = 1.0
        var y = 1.0
        var zoom = 0.45
        var turn = 0.0

        static var axes: [WritableKeyPath<Table, Double>] { [\.x, \.y, \.zoom, \.turn] }
    }

    /// The photos, three by three: the gallery's groups' pictures.
    static let photos = [
        "cat_fundamentals.png", "cat_driven.png", "cat_state.png",
        "cat_animation.png", "cat_basicinput.png", "cat_text.png",
        "cat_layout.png", "cat_styles.png", "cat_shapes.png",
    ]

    /// Where the table stands on every axis - handed on with `$`, never read
    /// in the body.
    @State private var table = Table()
    // listing: end

    // The table is moved by the hand of its own, so the example is not put in
    // a scroller.
    static let scrolls = false

    // And it takes the whole cell: the table wants the room.
    static let fills = true

    // listing: LightTableSample
    var body: some View {
        Grid {
            Rectangle(Palette.raised)
                .cornerRadius(14)

            LayoutEngine(Self.photos) { photo in
                ZStack { Image(ImageSource(photo)).contentMode(.fill) }
                    .shape(.roundedRectangle(12))
                    .clipsContent(true)
            } placements: { room, table in
                Self.photos.indices.map { place($0, table, room) }
            }
            .phase($table)
            // ONE FINGER OR TWO MOVE THE TABLE every way, a photo a rest...
            .input(.pan, drives: \.x, \.y)
            .snap(\.x, to: [0, 1, 2])
            .snap(\.y, to: [0, 1, 2])
            // ...while TWO SPREAD it from the whole table to one photo...
            .input(.magnification, drives: \.zoom)
            .snap(\.zoom, to: [0.45, 1])
            // ...and TURN the photos a quarter at a time, round and round.
            .input(.rotation(degreesPerUnit: 360), drives: \.turn)
            .snap(\.turn, to: [0, 0.25, 0.5, 0.75])
            .wraps(\.turn, every: 1)
            .motion(.spring(response: .milliseconds(420), damping: 0.82))
        }
        .clipsContent(true)
    }

    /// Where the photo at `index` lies: its square of the table, a photo's
    /// width and a gap apart, the photo the table is centred on in the middle
    /// of the room - all as near as the table stands - turned in its place.
    private func place(_ index: Int, _ table: Table, _ room: Rect) -> Placement {
        let side = min(room.width, room.height) * 0.8 * table.zoom
        let pitch = side * 1.12
        let (row, column) = index.quotientAndRemainder(dividingBy: 3)
        let x = room.width / 2 + (Double(column) - table.x) * pitch
        let y = room.height / 2 + (Double(row) - table.y) * pitch

        return Placement(
            Rect(x - side / 2, y - side / 2, side, side),
            transform: .rotate(table.turn * 360))
    }
    // listing: end

    var notes: (any View)? {
        Text("Drag to move across the table, a photo at a time. With two fingers - or a trackpad - spread or "
            + "pinch to come near a photo or see them all, and turn to turn the photos, while you move the table: "
            + "all at once. With a mouse, Control and the wheel zoom.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
