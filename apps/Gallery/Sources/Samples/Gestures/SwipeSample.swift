import StateUI

/// Which way a finger swiped, heard every way or narrowed to two.
struct SwipeSample: SampleContent, ExampleContent {
    // listing: SwipeSample
    @State private var swipe = ""

    @State private var narrowed = ""
    // listing: end

    static let id = "swipe"
    static let title = "Swipe"
    static let summary = "Which way a finger went, and which ways a view listens for."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: SwipeSample
    var body: some View {
        VStack {
            // What was swiped is read here, so every swipe builds this closure.
            DebugInfoLabel()

            ZStack {
                Text("Swipe across this box")
                    .fontSize(15)
                    .padding(32)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            // A recognizer that listens for nothing recognizes nothing, so
            // `direction` defaults to every way.
            .onSwiped { direction in
                swipe = Self.name(of: direction)
            }

            Text(swipe.isEmpty ? "nothing yet" : "Swiped \(swipe)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            ZStack {
                Text("Left or right, and a long way")
                    .fontSize(15)
                    .padding(32)
                    .horizontalTextAlignment(.center)
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            // Narrowed: two of the four ways, and a finger that must travel
            // 150 device units before anything fires.
            .onSwiped(direction: [.left, .right], threshold: 150) { direction in
                narrowed = Self.name(of: direction)
            }

            Text(narrowed.isEmpty ? "nothing yet" : "Swiped \(narrowed)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("The first box says nothing about `direction`, and a recognizer that "
            + "listens for nothing recognizes nothing - so it hears every way. The "
            + "second is narrowed to `.left` and `.right` with the threshold raised "
            + "to 150 device units: swipe up on it, or flick it short, and nothing "
            + "fires.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: SwipeSample
    private static func name(of direction: SwipeDirection) -> String {
        switch direction {
        case .left: return "left"
        case .right: return "right"
        case .up: return "up"
        case .down: return "down"
        default: return "somewhere"
        }
    }
    // listing: end
}
