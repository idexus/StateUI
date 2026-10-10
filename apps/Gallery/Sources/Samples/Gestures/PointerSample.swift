import StateUI

/// A pointer's hover, movement and button over one view.
struct PointerSample: SampleContent, ExampleContent {
    // listing: PointerSample
    @State private var pointer = Point(x: 0, y: 0)
    @State private var hovering = false
    @State private var pressing = false
    @State private var last = "nothing yet"
    // listing: end

    static let id = "pointer"
    static let title = "Pointer"
    static let summary = "A pointer entering, moving, pressing and letting go over one view."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: PointerSample
    var body: some View {
        ZStack {
            VStack {
                // Where the pointer is is read here, so every move builds this
                // closure - which is what a get on a per-report value costs.
                DebugInfoLabel()

                Text(hovering
                    ? "at \(Int(pointer.x)), \(Int(pointer.y))"
                    : "move a pointer over this box")
                    .fontSize(15)
                    .horizontalTextAlignment(.center)

                // Which of the five arrived last. Pressed and released say
                // where they happened; entered and exited carry no position at
                // all, and moved's is the line above.
                Text("last: \(last)")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .padding(horizontal: 40, vertical: 100)
        }
        .style(.card)
        // The box reacts, so its look is part of what it says: the outline is
        // the hover, the fill is the button held down.
        .stroke(hovering ? Palette.accent : Palette.outline)
        .lineWidth(hovering ? 2 : 1)
        .shape(.roundedRectangle(10))
        .background(pressing ? Palette.selected : .transparent)
        .onPointerEntered { hovering = true; last = "entered" }
        // The position is in the VIEW's own coordinates, not the window's.
        .onPointerMoved { point in
            pointer = point
            last = "moved"
        }
        .onPointerPressed { point in
            pressing = true
            last = "pressed at \(Int(point.x)), \(Int(point.y))"
        }
        .onPointerReleased { point in
            pressing = false
            last = "released at \(Int(point.x)), \(Int(point.y))"
        }
        // A button held down and taken out of the box can send exited with no
        // release after it, so the fill comes down here too.
        .onPointerExited { hovering = false; pressing = false; last = "exited" }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Five events: entered, exited, moved, pressed and released. Entered "
                + "and exited follow a hovering pointer - a mouse, a trackpad or a pen - "
                + "so a finger never sends them; a finger's touch still presses and releases.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Three of them carry a position, in the VIEW's own coordinates and not "
                + "the window's: moved says where the pointer is, pressed and released "
                + "where the button went down and came back up. Entered and exited carry "
                + "nothing but the fact.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
