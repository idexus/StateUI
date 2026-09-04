import StateUI

/// MAUI: SwipeGestureRecognizer.
struct SwipeSample: SampleContent {
    @State private var swipe = ""

    @State private var narrowed = ""

    static let id = "swipe"
    static let title = "Swipe"
    static let summary = "Which way a finger went, and which ways a view listens for."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var swipe = ""
        @State private var narrowed = ""

        VStack {
            Border {
                Label("Swipe across this box")
                    .padding(32)
            }
            .stroke(Palette.accent)
            .strokeShape(.roundRectangle(10))
            // A recognizer that listens for nothing recognizes nothing, so
            // `direction` defaults to every way.
            .onSwiped { direction in
                swipe = Self.name(of: direction)
            }

            Label(swipe.isEmpty ? "nothing yet" : "Swiped \\(swipe)")

            Border {
                Label("Left or right, and a long way")
                    .padding(32)
            }
            .stroke(Palette.accent)
            .strokeShape(.roundRectangle(10))
            // Narrowed: two of the four ways, and a finger that must travel
            // 150 device units before anything fires.
            .onSwiped(direction: [.left, .right], threshold: 150) { direction in
                narrowed = Self.name(of: direction)
            }

            Label(narrowed.isEmpty ? "nothing yet" : "Swiped \\(narrowed)")
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

    var example: Element {
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

            Border {
                Label("Left or right, and a long way")
                    .fontSize(15)
                    .padding(32)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            // Narrowed: two of the four ways, and a finger that must travel
            // 150 device units before anything fires.
            .onSwiped(direction: [.left, .right], threshold: 150) { direction in
                narrowed = Self.name(of: direction)
            }

            Label(narrowed.isEmpty ? "nothing yet" : "Swiped \(narrowed)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The first box says nothing about `direction`, and a recognizer that "
            + "listens for nothing recognizes nothing - so it hears every way. The "
            + "second is narrowed to `.left` and `.right` with the threshold raised "
            + "to 150 device units: swipe up on it, or flick it short, and nothing "
            + "fires.")
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
