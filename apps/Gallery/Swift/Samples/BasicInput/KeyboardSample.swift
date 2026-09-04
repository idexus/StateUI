import StateUI

/// MAUI: ContentPage.HideSoftInputOnTapped, VisualElement.Focus and Unfocus.
struct KeyboardSample: SampleContent {
    @State private var name = ""
    @State private var note = ""
    @State private var said = ""

    /// The field the two buttons reach - the control put into state, which is
    /// what an act needs and what a render cannot take away.
    @State private var first = ControlState<Entry>()

    static let id = "keyboard"
    static let title = "Keyboard"
    static let summary = "Three ways to give the keyboard back, and MAUI wrote two of them."

    /// The page property this sample is half about. MAUI recognizes the tap
    /// ALONGSIDE everything else, which is why this page still scrolls.
    static let hideSoftInputOnTapped: Bool? = true

    static let code = """
        @State private var name = ""
        @State private var note = ""
        @State private var said = ""

        @State private var first = ControlState<Entry>()

        // MAUI gives this to the PAGE, so it is asked for where a page can
        // answer - the same place a search box is asked for.
        var hideSoftInputOnTapped: Bool? { true }

        var content: Element {
            VStack {
                Entry($name)
                    .placeholder("Tap here, then tap the page beside it")
                    .assign(first)

                Entry($note)
                    .placeholder("The keyboard follows the focus")

                HStack {
                    Button("Focus the first")
                        .onClicked { try await first.focus() }

                    Button("Unfocus it")
                        .onClicked { try await first.unfocus() }
                }

                Button("Close the keyboard")
                    .onClicked {
                        said = try await SoftInput.hide()
                            ? "something had the keyboard, and has given it back"
                            : "nothing was focused - it was already down"
                    }

                Label(said)
            }
        }
        """

    var example: Element {
        VStack {
            Entry($name)
                .placeholder("Tap here, then tap the page beside it")
                .assign(first)

            Entry($note)
                .placeholder("The keyboard follows the focus")

            HStack {
                Button("Focus the first")
                    .horizontalOptions(.fill)
                    .onClicked { try await first.focus() }

                Button("Unfocus it")
                    .horizontalOptions(.fill)
                    .onClicked { try await first.unfocus() }
            }
            .spacing(8)

            Button("Close the keyboard")
                .onClicked {
                    said = try await SoftInput.hide()
                        ? "something had the keyboard, and has given it back"
                        : "nothing was focused - it was already down"
                }

            Label(said.isEmpty ? "Nothing said yet." : said)
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("TAPPING BESIDE A FIELD closes the keyboard, because the page says "
                + "`hideSoftInputOnTapped`. It is MAUI's own property, and MAUI recognizes "
                + "that tap alongside everything else - so this page still scrolls, and "
                + "both buttons still answer, which a view laid over the content to catch "
                + "touches could not promise.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A BUTTON THAT KNOWS THE FIELD says so: `.unfocus()` on the state the "
                + "field was assigned - `.assign(first)` puts the control into it, and "
                + "the act is aimed at that control.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A BUTTON THAT DOES NOT asks instead: `SoftInput.hide()` names no view, "
                + "because which control the reader touched last is not something this side "
                + "knows. The host asks the page, and answers whether anything was focused.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON A DESKTOP THE ANSWER IS ALWAYS YES, and that is the platform "
                + "rather than this act: on Windows a clicked button takes the focus, so "
                + "by the time the handler asks, the button just pressed is what holds "
                + "it. The act still unfocuses whatever the page has - but the wording "
                + "above is a phone's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It reaches the navigation bar's search box too - see the Search sample, "
                + "where it is what puts the back button back on iOS.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
