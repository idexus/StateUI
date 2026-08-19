import StateUI

/// MAUI: INavigation.ModalStack, and the array this side keeps it in step with.
struct ModalSample: SampleContent {
    /// Where the gallery is. The modal stack is part of it: presenting is one
    /// more thing this application's navigation model can do.
    let nav: Navigation

    static let id = "modal"
    static let title = "Presenting over everything"
    static let summary = "A modal page is a second array on the window - and a sheet you draw yourself."

    static let code = """
        enum Sheet: Hashable {
            case page(UIModalPresentationStyle)
            case card
        }

        @State private var sheets: [Sheet] = []

        struct MainWindow: Window {
            let sheets: Binding<[Sheet]>

            var modalStack: ModalStack? {
                ModalStack(sheets) { sheet in
                    switch sheet {
                    case .page(let style): ModalPage(sheets: sheets, style: style)
                    case .card:            CardSheetPage(sheets: sheets)
                    }
                }
            }

            var content: Page { HomePage(sheets: sheets) }
        }

        // -- PRESENTING AND CLOSING --

        Button("Present")
            .onClicked { sheets.append(.page(.pageSheet)) }

        Button("Close")             // written on the SHEET: a modal covers
            .onClicked { sheets.removeLast() }     // the bar it would use

        // -- A SHEET WITH NOTHING PLATFORM-SPECIFIC IN IT --

        struct CardSheetPage: ContentPage {
            let sheets: Binding<[Sheet]>

            var modalPresentationStyle: UIModalPresentationStyle? { .overFullScreen }
            var backgroundColor: Color? { .transparent }

            @State private var lift = 420.0   // below the bottom of the screen

            var content: Element {
                let lift = $lift              // a local, not a capture list

                return Grid {
                    VStack {
                        Label("A sheet with nothing platform-specific in it")

                        Button("Close")
                            .onClicked { sheets.wrappedValue.removeLast() }
                    }
                    .verticalOptions(.end)
                    .translationY($lift)      // ARMS the property
                    .onLoaded {
                        try await lift.animateTo(0, length: 260, easing: .cubicOut)
                    }
                }
            }
        }
        """

    var content: Element {
        VStack {
            Label("A modal page is not on any stack and not in any tab: it covers the "
                + "WINDOW, bars and all. So it hangs off the window rather than off a "
                + "page - `.modalStack($sheets)`, a second array beside the navigation "
                + "path, with the same protocol: presenting is `append`, closing is "
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
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label("`var modalPresentationStyle: UIModalPresentationStyle?` is MAUI's iOS "
                + "platform-specific, written on the page that is PRESENTED. A page "
                + "sheet is a card the reader can drag down - try it, and watch the "
                + "array shorten by itself. On Android and Windows both buttons give the "
                + "same full-screen page: UIKit is the only one of the four with a "
                + "choice here.")
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
                + "state, armed by the modifier that reads it - `.opacity($dim)`, "
                + "`.translationY($lift)` - and walked by `animateTo`, which writes "
                + "the target into the state at once: the tree says where the card is "
                + "going and the control walks there. Both start from `.onLoaded`, "
                + "because the handler that PRESENTED the page ran before any of these "
                + "views existed, so the entrance belongs to the views.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHAT IS PRESENTED")

            Label(nav.sheets.isEmpty
                ? "nothing - the array is empty"
                : nav.sheets.map { "\($0)" }.joined(separator: " › "))
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)

            Label("Read from the same array the window is built from, so this page and "
                + "the screen cannot disagree. A sheet dragged down writes it before "
                + "this label is drawn again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
