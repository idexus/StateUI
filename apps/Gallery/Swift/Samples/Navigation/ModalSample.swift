import StateUI

/// MAUI: INavigation.ModalStack, and the array this side keeps it in step with.
struct ModalSample: SampleContent {
    /// Where the gallery is. The modal stack is part of it: presenting is one
    /// more thing this gallery's navigation model can do.
    let nav: Navigation

    static let id = "modal"
    static let title = "Presenting over everything"
    static let summary = "A modal page is a second array on the window - and a sheet you draw yourself."

    static let code = """
        enum Sheet: Hashable {
            case page(UIModalPresentationStyle)
            case card
        }

        struct MainWindow: Window {
            @State private var sheets: [Sheet] = []

            var page: any Page { HomePage(sheets: $sheets) }
        }

        struct HomePage: ContentPage {
            @Environment private var window: WindowSession
            @Binding var sheets: [Sheet]

            var content: any View {
                Label("Over this page, what the array holds")
                    .onCreated {
                        // Written once: the stack reads the array as the
                        // window builds.
                        window.modalStack = ModalStack($sheets) { sheet in
                            switch sheet {
                            case .page(let style): ModalPage(sheets: $sheets, style: style)
                            case .card:            CardSheetPage(sheets: $sheets)
                            }
                        }
                    }
            }
        }

        // -- PRESENTING AND CLOSING --

        Button("Present")
            .onClicked { sheets.append(.page(.fullScreen)) }

        Button("Page sheet")        // the same page, drawn differently -
            .onClicked { sheets.append(.page(.pageSheet)) }   // see below

        Button("Automatic")
            .onClicked { sheets.append(.page(.automatic)) }

        Button("Close")             // written on the SHEET: a modal covers
            .onClicked { sheets.removeLast() }     // the bar it would use

        // -- AND WHAT THE PRESENTED PAGE SAYS ABOUT ITSELF --

        struct ModalPage: ContentPage {
            @Binding var sheets: [Sheet]
            let style: UIModalPresentationStyle
            @Environment private var page: PageSession

            var content: any View {
                Button("Close")
                    .onClicked { sheets.removeLast() }
                    // The PRESENTED page's own, so a sheet knows what it
                    // looks like wherever it is presented from. iOS and Mac
                    // Catalyst read it; Android and Windows cover the whole
                    // window whatever it says.
                    .onCreated { page.modalPresentationStyle = style }
            }
        }

        // -- A SHEET WITH NOTHING PLATFORM-SPECIFIC IN IT --

        struct CardSheetPage: ContentPage {
            @Binding var sheets: [Sheet]
            @Environment private var page: PageSession

            // How far below its place the card starts, and goes back to -
            // off the bottom of the screen, however tall the card is.
            private static let travel = 420.0

            @State private var shade = 0.0            // how dark the backdrop is
            @State private var drop = Self.travel     // how far below its place the card is

            var content: any View {
                let dimming = $shade                  // locals, not a capture list
                let rising = $drop

                return Grid {
                    // The backdrop, and the way out every sheet has: a tap
                    // beside the card.
                    BoxView()
                        .color(Color("#000000"))
                        .opacity($shade)              // DRIVEN by the state
                        .onTapped { await close() }

                    VStack {
                        Label("A sheet with nothing platform-specific in it")

                        Button("Close")
                            .onClicked { await close() }
                    }
                    .verticalOptions(.end)
                    .translationY($drop)              // DRIVEN by the state
                }
                .onCreated {
                    page.modalPresentationStyle = .overFullScreen
                    page.backgroundColor = .transparent
                }
                // The entrance, as the page appears - once the platform has
                // put it up, so the movement is seen: the backdrop darkens
                // and the card rises, together.
                .onChanged(page.phase) {
                    guard page.phase == .appearing else { return }

                    async let faded: Bool = dimming.journey.move(to: 0.45, .eased(220))
                    async let risen: Bool = rising.journey.move(to: 0, .eased(260, .cubicOut))

                    _ = try? await faded
                    _ = try? await risen
                }
            }

            // The card goes back down and the backdrop fades, and only THEN
            // is the page taken off the array - shortened first, there would
            // be nothing left to move.
            private func close() async {
                let sinking = $drop
                let dimming = $shade

                async let sunk: Bool = sinking.journey.move(to: Self.travel, .eased(200, .cubicIn))
                async let faded: Bool = dimming.journey.move(to: 0, .eased(200))

                _ = try? await sunk
                _ = try? await faded

                sheets.removeLast()
            }
        }

        // -- WHAT IS PRESENTED --

        VStack {
            // The sheets are read here, so presenting one and closing it
            // build this closure.
            DebugInfoLabel()

            Label(sheets.isEmpty ? "nothing" : sheets.map { "\\($0)" }.joined(separator: " › "))
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("A modal page is not on any stack and not in any tab: it covers the "
                + "WINDOW, bars and all. So it hangs off the window rather than off a "
                + "page - `window.modalStack = ModalStack($sheets) { … }`, a "
                + "second array beside the navigation path, with the same protocol: "
                + "presenting is `append`, closing is "
                + "`removeLast()`, and a sheet the reader dismisses truncates it.")
                .fontSize(13)
                .textColor(Palette.subtle)

            SectionTitle("THE PLATFORM'S OWN")

            Button("Present a page")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.present(.page(.fullScreen)) }

            Label("Over the whole window, which is what every platform does with a modal "
                + "page. The one presented has its own Close button, because there is no "
                + "bar left to put one on.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("AND HOW APPLE DRAWS IT")

            HStack {
                Button("Page sheet")
                    .padding(16, 8)
                    .onClicked { nav.present(.page(.pageSheet)) }

                Button("Form sheet")
                    .padding(16, 8)
                    .onClicked { nav.present(.page(.formSheet)) }

                Button("Automatic")
                    .padding(16, 8)
                    .onClicked { nav.present(.page(.automatic)) }
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label("One page, four buttons: `ModalPage` writes whatever it was handed "
                + "into its session's `modalPresentationStyle`, and prints it on "
                + "itself. A page sheet is a card the "
                + "reader can drag down - try it, and watch the array shorten by itself. "
                + "A form sheet is a panel smaller than the screen with the page dimmed "
                + "around it. `.automatic` is whatever the system would choose, which "
                + "modern iOS answers with a page sheet.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The property is Apple's own, so it is honoured on iOS and Mac "
                + "Catalyst and NOWHERE ELSE: on "
                + "Android and Windows all four buttons give the same full-screen page, "
                + "those platforms presenting every modal over the whole window. A page "
                + "written for a sheet therefore has to look right full screen too.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("OR DRAW THE SHEET YOURSELF")

            Button("Slide one up from the bottom")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.present(.card) }

            Label("The same movement on all four platforms, because none of it is the "
                + "platform's: a modal page presented `.overFullScreen` with a "
                + "transparent background, a dimmed backdrop that fades in, and a card "
                + "translated off the bottom that slides up. Both are the page's own "
                + "state, DRIVEN by the modifier that reads it - `.opacity($shade)`, "
                + "`.translationY($drop)` - and sent by `journey.move(to:)`, which writes "
                + "the target into the state at once: the state says where the card is "
                + "going and the host carries it there on its own frames, with nothing "
                + "described in between. Both start as the page appears - its phase "
                + "turning `appearing`, MAUI's Page.Appearing - because the handler that PRESENTED "
                + "the page ran before any of these views existed, and the platform's own "
                + "presentation runs before the page can be seen.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHAT IS PRESENTED")

            Label(nav.sheets.isEmpty
                ? "nothing - the array is empty"
                : nav.sheets.map { "\($0)" }.joined(separator: " › "))
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)

        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Read from the same array the window is built from, so this page and "
            + "the screen cannot disagree. A sheet dragged down writes it before "
            + "this label is drawn again.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
