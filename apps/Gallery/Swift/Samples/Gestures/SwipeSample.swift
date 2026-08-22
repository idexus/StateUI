import StateUI

/// MAUI: SwipeGestureRecognizer.
struct SwipeSample: SampleContent {
    @State private var swipe = ""

    static let id = "swipe"
    static let title = "Swipe"
    static let summary = "Which way a finger went, and which ways a view listens for."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var swipe = ""

        VStack {
            Border {
                Label("Swipe across this box")
                    .padding(32)
            }
            .stroke(Palette.accent)
            .strokeShape(.roundRectangle(10))
            // A recognizer that listens for nothing recognizes nothing, so
            // `direction` defaults to every way;
            // .onSwiped(direction:threshold:) narrows it and says how far a
            // finger has to travel.
            .onSwiped { direction in
                swipe = Self.name(of: direction)
            }

            Label(swipe.isEmpty ? "nothing yet" : "Swiped \\(swipe)")
        }

        private static func name(of direction: SwipeDirection) -> String {
            switch direction {
            case .left: return "left"
            case .right: return "right"
            case .up: return "up"
            case .down: return "down"
            default: return "somewhere"
            }
        }
        """

    var content: Element {
        VStack {
            Border {
                Label("Swipe across this box")
                    .fontSize(15)
                    .padding(32)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .onSwiped { direction in
                swipe = Self.name(of: direction)
            }

            Label(swipe.isEmpty ? "nothing yet" : "Swiped \(swipe)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("A recognizer that listens for nothing recognizes nothing, so "
            + "`direction` defaults to every way. The threshold is how far the "
            + "finger must travel, in device units.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    private static func name(of direction: SwipeDirection) -> String {
        switch direction {
        case .left: return "left"
        case .right: return "right"
        case .up: return "up"
        case .down: return "down"
        default: return "somewhere"
        }
    }
}
