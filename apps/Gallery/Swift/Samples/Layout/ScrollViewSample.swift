import StateUI

/// MAUI: ScrollView.
struct ScrollViewSample: SampleContent {
    @State private var scrolled = 0.0

    @State private var scroller = ControlState<ScrollView>()

    static let id = "scrollView"
    static let title = "ScrollView"
    static let summary = "A scrollable container - its offset reported one way, and set by an act."

    static let code = """
        @State private var scrolled = 0.0

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

            Label("`scrollTo` is an act on the view's id, the WebView pattern - MAUI's "
                + "ScrollToAsync, the `Async` dropped - and the handler is suspended "
                + "until the glide finishes. The offset comes back the other way: "
                + "ScrollY has no setter worth writing to, so it is reported into the "
                + "binding.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ScrollY has no event of its own, so it is watched through "
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
}
