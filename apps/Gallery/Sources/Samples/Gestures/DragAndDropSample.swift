import StateUI

/// Text dragged from one view and dropped on another.
struct DragAndDropSample: SampleContent, ExampleContent {
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var basket: [String] = []
    @State private var over = false
    @State private var finished = "nothing dragged yet"

    static let id = "dragAndDrop"
    static let title = "Drag and drop"
    static let summary = "Carrying something from one view to another."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var basket: [String] = []
        @State private var over = false
        @State private var finished = "nothing dragged yet"

        VStack {
            // The two runs and what the last drag did are read here, so a drop
            // builds this closure.
            DebugInfoLabel()

            HStack {
                ForEach(items) { item in
                    ZStack {
                        Label(item)
                            .padding(12, 8)
                    }
                    .style("Card")
                    .stroke(Palette.accent)
                    .shape(.roundedRectangle(8))
                    // What travels is decided before the drag starts: a
                    // native drag session needs its payload at once.
                    .draggable(text: item)
                    // The view that was DRAGGED hears when its own drag ends,
                    // wherever it ended.
                    .onDropCompleted { finished = "\\(item): drop finished" }
                    .id(item)
                }
            }

            Label(finished)

            ZStack {
                VStack {
                    Label(over
                        ? "let go to drop it"
                        : (basket.isEmpty ? "nothing yet" : "\\(basket.count) dropped"))

                    ForEach(Array(basket.enumerated()), id: \\.offset) { pair in
                        Label(pair.element)
                    }
                }
                .padding(24)
            }
            .style("Card")
            // Lit while something is over it and dark again once it leaves,
            // which is what the two events are for.
            .stroke(over ? Palette.accent : Palette.outline)
            .strokeWidth(over ? 2 : 1)
            .shape(.roundedRectangle(10))
            .background(over ? Palette.selected : Palette.raised)
            .onDragOver { over = true }
            .onDragLeave { over = false }
            // A drop is not a leave, so the light comes down here too.
            .onDrop { text in
                basket.append(text)
                over = false
            }

            Button("Empty it")
                .isEnabled(!basket.isEmpty)
                .onClicked { basket = [] }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            SectionTitle("Drag from here")

            HStack {
                ForEach(items) { item in
                    ZStack {
                        Label(item)
                            .fontSize(14)
                            .padding(12, 8)
                    }
                    .style("Card")
                    .stroke(Palette.accent)
                    .strokeWidth(1)
                    .shape(.roundedRectangle(8))
                    .draggable(text: item)
                    // The view that was DRAGGED hears when its own drag ends,
                    // wherever it ended.
                    .onDropCompleted { finished = "\(item): drop finished" }
                    .id(item)
                }
            }
            .spacing(8)

            Label(finished)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            SectionTitle("Drop here")

            ZStack {
                VStack {
                    Label(over
                        ? "let go to drop it"
                        : (basket.isEmpty ? "nothing yet" : "\(basket.count) dropped"))
                        .fontSize(15)
                        .horizontalTextAlignment(.center)

                    ForEach(Array(basket.enumerated()), id: \.offset) { pair in
                        Label(pair.element)
                            .fontSize(13)
                            .textColor(Palette.subtle)
                            .horizontalTextAlignment(.center)
                    }
                }
                .spacing(4)
                .padding(24)
            }
            .style("Card")
            // Lit while something is over it and dark again once it leaves,
            // which is what the two events are for.
            .stroke(over ? Palette.accent : Palette.outline)
            .strokeWidth(over ? 2 : 1)
            .shape(.roundedRectangle(10))
            .background(over ? Palette.selected : Palette.raised)
            .onDragOver { over = true }
            .onDragLeave { over = false }
            // A drop is not a leave, so the light comes down here too.
            .onDrop { text in
                basket.append(text)
                over = false
            }

            Button("Empty it")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .isEnabled(!basket.isEmpty)
                .onClicked { basket = [] }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("What travels is a STRING, decided before the drag starts: a native "
                + "drag session needs its payload at once, so `draggable(text:)` says it "
                + "up front.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Reading what was dropped is asynchronous - it may be coming from "
                + "another application - so the host reads it, and `onDrop` runs with the "
                + "text when there is something to say.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`onDragOver` runs again and again while a drag is held over the "
                + "target, not once, so it SETS the highlight rather than counting; "
                + "`onDragLeave` runs when the drag goes away without being let go. A "
                + "drop is not a leave, so `onDrop` takes the highlight down as well.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both of those belong to a view that ACCEPTS a drop, and `onDrop` is "
                + "what makes a view one - written without it, neither ever runs. "
                + "`onDropCompleted` is the other end: it belongs to the view that was "
                + "dragged, so it needs `draggable(text:)` beside it, and it runs when "
                + "that drag ends wherever it ended - over the basket, or over nothing "
                + "at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
