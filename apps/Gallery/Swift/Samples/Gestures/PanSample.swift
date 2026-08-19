import StateUI

/// MAUI: PanGestureRecognizer.
struct PanSample: SampleContent {
    @State private var pan = Point(x: 0, y: 0)
    @State private var panLive = Point(x: 0, y: 0)

    static let id = "pan"
    static let title = "Pan"
    static let summary = "Dragging a view about, from where it was to where it is let go."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var pan = Point(x: 0, y: 0)
        @State private var panLive = Point(x: 0, y: 0)

        VStack {
            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .widthRequest(64)
                    .heightRequest(64)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    .translationX(panLive.x)
                    .translationY(panLive.y)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            panLive = Point(x: pan.x + update.totalX, y: pan.y + update.totalY)
                        case .completed:
                            pan = panLive
                        case .canceled:
                            panLive = pan
                        case .started:
                            break
                        }
                    }
            }
            .heightRequest(200)

            Label("Moved \\(Int(panLive.x)), \\(Int(panLive.y))")

            Button("Put it back")
                .onClicked {
                    pan = Point(x: 0, y: 0)
                    panLive = pan
                }
        }
        """

    var content: Element {
        VStack {
            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(64)
                    .heightRequest(64)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    .translationX(panLive.x)
                    .translationY(panLive.y)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            panLive = Point(x: pan.x + update.totalX, y: pan.y + update.totalY)
                        case .completed:
                            pan = panLive
                        case .canceled:
                            panLive = pan
                        case .started:
                            break
                        }
                    }
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .heightRequest(200)

            Label("Moved \(Int(panLive.x)), \(Int(panLive.y))")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Button("Put it back")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked {
                    pan = Point(x: 0, y: 0)
                    panLive = pan
                }

            Label("The totals are measured from where the pan BEGAN, not from the last "
                + "report - which is why the running case adds them to where the view "
                + "was, and the completed case is what commits the move.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
