import StateUI

/// MAUI: PointerGestureRecognizer.
struct PointerSample: SampleContent {
    @State private var pointer = Point(x: 0, y: 0)
    @State private var hovering = false

    static let id = "pointer"
    static let title = "Pointer"
    static let summary = "A mouse, a trackpad or a pen - the gestures a touch-only device never sends."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var pointer = Point(x: 0, y: 0)
        @State private var hovering = false

        VStack {
            Border {
                Label(hovering
                    ? "at \\(Int(pointer.x)), \\(Int(pointer.y))"
                    : "move a pointer over this box")
                    .padding(40)
            }
            // The box reacts, so the stroke is part of what it says.
            .stroke(hovering ? Palette.accent : Palette.outline)
            .strokeThickness(hovering ? 2 : 1)
            .strokeShape(.roundRectangle(10))
            .onPointerEntered { hovering = true }
            .onPointerExited { hovering = false }
            .onPointerMoved { point in pointer = point }
        }

        // The position is in the VIEW's own coordinates, not the window's.
        """

    var content: Element {
        VStack {
            Border {
                Label(hovering
                    ? "at \(Int(pointer.x)), \(Int(pointer.y))"
                    : "move a pointer over this box")
                    .fontSize(15)
                    .padding(40)
                    .horizontalTextAlignment(.center)
            }
            .stroke(hovering ? Palette.accent : Palette.outline)
            .strokeThickness(hovering ? 2 : 1)
            .strokeShape(.roundRectangle(10))
            .onPointerEntered { hovering = true }
            .onPointerExited { hovering = false }
            .onPointerMoved { point in pointer = point }

            Label("The position is in the VIEW's own coordinates, not the window's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Five events, one recognizer: entered, exited, moved, pressed and "
                + "released all come from the same PointerGestureRecognizer, which is "
                + "why a view carries one of each kind however many handlers it has.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
