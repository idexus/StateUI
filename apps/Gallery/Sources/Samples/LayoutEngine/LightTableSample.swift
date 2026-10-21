import StateUI

/// Photos on a light table: a pan, a pinch and a rotation at once, each
/// driving an axis of one phase.
struct LightTableSample: SampleContent, ExampleContent {
    static let id = "lightTable"
    static let title = "Light table"
    static let summary = "Photos on a light table - pan, pinch and turn them, all at once."

    // listing: LightTableSample
    /// THE PHASE: which photo the table is centered on, across and down, how
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

    /// Whether the table rests on a photo and the photos on a quarter turn:
    /// read in the body, so the switch declares the axes again.
    @State private var snaps = true
    // listing: end

    // The table is moved by the hand of its own, so the example is not put in
    // a scroller.
    static let scrolls = false

    // And it takes the whole cell: the table wants the room.
    static let fills = true

    // listing: LightTableSample
    var body: some View {
        Grid {
            Grid {
                photosOnTheTable
            }
            .gridRow(0)
            .clipsContent(true)

            SwitchRow(
                "Snap",
                Binding(
                    get: { snaps },
                    set: { snapping in
                        snaps = snapping
                        // SNAPPING AGAIN, the table travels to the photo and
                        // the quarter turn nearest where it was left.
                        if snapping {
                            table.x = table.x.rounded()
                            table.y = table.y.rounded()
                            table.turn = (table.turn * 4).rounded() / 4
                        }
                    }))
            .horizontalAlignment(.center)
            .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }

    /// The photos, placed from every axis of the table.
    private var photosOnTheTable: some View {
        LayoutEngine(Self.photos) { photo in
            ZStack { Image(ImageSource(photo)).contentMode(.fill) }
                .shape(.roundedRectangle(12))
                .clipsContent(true)
        } placements: { room, table in
            Self.photos.indices.map { place($0, table, room) }
        }
        .phase($table)
        // ONE FINGER OR TWO MOVE THE TABLE every way - one axis scrolled
        // across, one down - resting on a photo, or, not snapping, anywhere...
        .axis(\.x, input: .scroll(.horizontal), range: 0...2, snaps: snaps ? .every(1) : nil)
        .axis(\.y, input: .scroll(.vertical), range: 0...2, snaps: snaps ? .every(1) : nil)
        // ...while TWO SPREAD it anywhere from the whole table to one photo,
        // coming back only from past either end...
        .axis(\.zoom, input: .magnification, range: 0.45...1)
        // ...and TURN the photos a quarter at a time, or freely, round and
        // round.
        .axis(
            \.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, snaps: snaps ? .every(0.25) : nil,
            wraps: true)
        .motion(.spring(response: .milliseconds(420), damping: 0.82))
    }

    /// Where the photo at `index` lies: its square of the table, a photo's
    /// width and a gap apart, the photo the table is centered on in the middle
    /// of the room - all as near as the table stands, the whole table in the
    /// room at its farthest - turned in its place.
    private func place(_ index: Int, _ table: Table, _ room: Rect) -> Placement {
        let side = min(room.width, room.height) * 0.65 * table.zoom
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
            + "pinch to come as near as you like, from the whole table to one photo, and turn to turn the photos a "
            + "quarter at a time, while you move the table: all at once. With a mouse, Control and the wheel zoom, and a "
            + "drag with Alt (⌥) held turns and zooms round the middle. "
            + "Switch Snap off, and the table and the photos rest wherever you leave them.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
