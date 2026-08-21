import StateUI

/// MAUI: ScrollView.
struct ScrollViewSample: SampleContent {
    @State private var scrolled = 0.0

    @State private var across = 0.0

    @State private var scroller = ControlState<ScrollView>()

    static let id = "scrollView"
    static let title = "ScrollView"
    static let summary = "A scrollable container - its offset reported one way, and set by an act."

    static let code = """
        @State private var scrolled = 0.0
        @State private var across = 0.0

        @State private var scroller = ControlState<ScrollView>()

        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \\(line)")
                            .padding(8, 6)
                    }
                }
            }
            .assign(scroller)
            .heightRequest(160)
            .scrollY($scrolled)

            Label("Scrolled to \\(Int(scrolled))")

            HStack {
                Button("Top")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                Button("Line 9")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
            }

            // The same report, sideways, from a scroller that runs that way.
            ScrollView {
                HStack {
                    ForEach(1...12) { column in
                        Label("Column \\(column)")
                            .padding(12, 8)
                    }
                }
            }
            .orientation(.horizontal)
            .scrollX($across)

            Label("Scrolled across \\(Int(across))")

            // The same twelve rows twice, so the bar is the only difference.
            Grid {
                ScrollView {
                    VStack {
                        ForEach(1...12) { line in
                            Label("Line \\(line)")
                        }
                    }
                }
                .verticalScrollBarVisibility(.always)
                .heightRequest(110)

                ScrollView {
                    VStack {
                        ForEach(1...12) { line in
                            Label("Line \\(line)")
                        }
                    }
                }
                .verticalScrollBarVisibility(.never)
                .heightRequest(110)
                .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)
        }
        """

    var content: Element {
        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \(line)")
                            .fontSize(15)
                            .padding(8, 6)
                    }
                }
            }
            .assign(scroller)
            .heightRequest(160)
            .scrollY($scrolled)

            Label("Scrolled to \(Int(scrolled))")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Top")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 0) }

                Button("Line 9")
                    .onClicked { try await scroller.scrollTo(x: 0, y: 240) }
            }
            .spacing(12)
            .horizontalOptions(.center)

            SectionTitle("SIDEWAYS")

            // ScrollX is the same report along the other axis, so what it takes
            // is a scroller that runs that way - drag the row and watch it.
            ScrollView {
                HStack {
                    ForEach(1...12) { column in
                        Label("Column \(column)")
                            .fontSize(13)
                            .textColor(Palette.onAccent)
                            .backgroundColor(Palette.accent)
                            .padding(12, 8)
                    }
                }
                .spacing(8)
            }
            .orientation(.horizontal)
            .scrollX($across)

            Label("Scrolled across \(Int(across))")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            SectionTitle("THE BAR DOWN THE SIDE")

            // The same twelve rows twice, so the bar is the only thing that
            // differs between them.
            Grid {
                barCase(.always, "verticalScrollBarVisibility(.always)")

                barCase(.never, "verticalScrollBarVisibility(.never)")
                    .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            Label("`.never` takes the bar away and nothing brings it back; `.always` asks "
                + "for one that stands there whether or not a drag is under way. Where the "
                + "platform draws an OVERLAY bar that fades on its own - macOS, Android - "
                + "the two look alike until the scroller is dragged.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`scrollTo` is an act on the view's id, the WebView pattern - MAUI's "
                + "ScrollToAsync, the `Async` dropped - and the handler is suspended "
                + "until the glide finishes. The offset comes back the other way: "
                + "ScrollX and ScrollY have no setter worth writing to, so each is "
                + "reported into a binding.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Neither offset has an event of its own, so both are watched through "
                + "PropertyChanged - and only because the tree asked for it. Width and "
                + "Height raise it at every measure, so a standing subscription per "
                + "control would cost real work for an answer nobody wanted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A ScrollView holds ONE view; several children are wrapped in a stack "
                + "by the renderer rather than all but the first being dropped.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One short scroller with the setting that made it named underneath, so
    /// the pair reads as one difference rather than two scrollers. A stack
    /// rather than an Element, so the caller can say which column it goes in.
    private func barCase(_ visibility: ScrollBarVisibility, _ caption: String) -> VStack {
        VStack {
            ScrollView {
                VStack {
                    ForEach(1...12) { line in
                        Label("Line \(line)")
                            .fontSize(13)
                            .padding(6, 4)
                    }
                }
            }
            .verticalScrollBarVisibility(visibility)
            .heightRequest(110)

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(6)
    }
}
