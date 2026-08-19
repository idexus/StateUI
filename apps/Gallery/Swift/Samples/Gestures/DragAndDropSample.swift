import StateUI

/// MAUI: DragGestureRecognizer and DropGestureRecognizer.
struct DragAndDropSample: SampleContent {
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var basket: [String] = []

    static let id = "dragAndDrop"
    static let title = "Drag and drop"
    static let summary = "Carrying something from one view to another."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var basket: [String] = []

        VStack {
            HStack {
                ForEach(items) { item in
                    Border {
                        Label(item)
                            .padding(12, 8)
                    }
                    .stroke(Palette.accent)
                    .strokeShape(.roundRectangle(8))
                    // What travels is decided before the drag starts: MAUI
                    // wants the data package filled the moment it begins.
                    .draggable(text: item)
                    .id(item)
                }
            }

            Border {
                VStack {
                    Label(basket.isEmpty ? "nothing yet" : "\\(basket.count) dropped")

                    ForEach(Array(basket.enumerated()), id: \\.offset) { pair in
                        Label(pair.element)
                    }
                }
                .padding(24)
            }
            .stroke(Palette.outline)
            .strokeShape(.roundRectangle(10))
            .onDrop { text in basket.append(text) }

            Button("Empty it")
                .isEnabled(!basket.isEmpty)
                .onClicked { basket = [] }
        }
        """

    var content: Element {
        VStack {
            SectionTitle("DRAG FROM HERE")

            HStack {
                ForEach(items) { item in
                    Border {
                        Label(item)
                            .fontSize(14)
                            .padding(12, 8)
                    }
                    .stroke(Palette.accent)
                    .strokeThickness(1)
                    .strokeShape(.roundRectangle(8))
                    .draggable(text: item)
                    .id(item)
                }
            }
            .spacing(8)

            SectionTitle("DROP HERE")

            Border {
                VStack {
                    Label(basket.isEmpty ? "nothing yet" : "\(basket.count) dropped")
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
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .onDrop { text in basket.append(text) }

            Button("Empty it")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .isEnabled(!basket.isEmpty)
                .onClicked { basket = [] }

            Label("What travels is a STRING, decided before the drag starts. MAUI wants "
                + "the data package filled the moment the drag begins, and this side "
                + "could not be asked in time - so `draggable(text:)` says it up front.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Reading what was dropped is asynchronous - it may be coming from "
                + "another application - so the await happens on the C# side, and the "
                + "handler here runs when there is something to say.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
