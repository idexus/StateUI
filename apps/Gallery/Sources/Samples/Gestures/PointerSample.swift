import StateUI

/// A pointer's hover, movement and button over one view.
struct PointerSample: SampleContent, ExampleContent {
    @State private var pointer = Point(x: 0, y: 0)
    @State private var hovering = false
    @State private var pressing = false
    @State private var last = "nothing yet"

    static let id = "pointer"
    static let title = "Pointer"
    static let summary = "A mouse, a trackpad or a pen - the gestures a touch-only device never sends."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var pointer = Point(x: 0, y: 0)
        @State private var hovering = false
        @State private var pressing = false
        @State private var last = "nothing yet"

        Border {
            VStack {
                // Where the pointer is is read here, so every move builds this
                // closure - which is what a get on a per-report value costs.
                DebugInfoLabel()

                Label(hovering
                    ? "at \\(Int(pointer.x)), \\(Int(pointer.y))"
                    : "move a pointer over this box")

                // Which of the five arrived last. Pressed and released say
                // where they happened; entered and exited carry no position at
                // all, and moved's is the line above.
                Label("last: \\(last)")
            }
            .padding(40)
        }
        // The box reacts, so its look is part of what it says: the outline is
        // the hover, the fill is the button held down.
        .stroke(hovering ? Palette.accent : Palette.outline)
        .strokeThickness(hovering ? 2 : 1)
        .strokeShape(.roundRectangle(10))
        .background(pressing ? Palette.selected : Palette.raised)
        .onPointerEntered { hovering = true; last = "entered" }
        .onPointerMoved { point in
            pointer = point
            last = "moved"
        }
        .onPointerPressed { point in
            pressing = true
            last = "pressed at \\(Int(point.x)), \\(Int(point.y))"
        }
        .onPointerReleased { point in
            pressing = false
            last = "released at \\(Int(point.x)), \\(Int(point.y))"
        }
        // A button held down and taken out of the box can send exited with no
        // release after it, so the fill comes down here too.
        .onPointerExited { hovering = false; pressing = false; last = "exited" }

        // The position is in the VIEW's own coordinates, not the window's.
        """

    var content: any View {
        Border {
            VStack {
                DebugInfoLabel()

                Label(hovering
                    ? "at \(Int(pointer.x)), \(Int(pointer.y))"
                    : "move a pointer over this box")
                    .fontSize(15)
                    .horizontalTextAlignment(.center)

                // Which of the five arrived last. Pressed and released say
                // where they happened; entered and exited carry no position at
                // all, and moved's is the line above.
                Label("last: \(last)")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .padding(40, 100)
        }
        // The box reacts, so its look is part of what it says: the outline is
        // the hover, the fill is the button held down.
        .stroke(hovering ? Palette.accent : Palette.outline)
        .strokeThickness(hovering ? 2 : 1)
        .strokeShape(.roundRectangle(10))
        .background(pressing ? Palette.selected : Palette.raised)
        .onPointerEntered { hovering = true; last = "entered" }
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

    var notes: Element? {
        VStack {
            Label("Five events: entered, exited, moved, pressed and released. A pointer "
                + "is a mouse, a trackpad or a pen, so on a touch-only device none of "
                + "them fires.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Three of them carry a position, in the VIEW's own coordinates and not "
                + "the window's: moved says where the pointer is, pressed and released "
                + "where the button went down and came back up. Entered and exited carry "
                + "nothing but the fact.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
