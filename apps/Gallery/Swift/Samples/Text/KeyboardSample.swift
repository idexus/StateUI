import StateUI

/// MAUI: ContentPage.HideSoftInputOnTapped, VisualElement.Focus and Unfocus.
struct KeyboardSample: SampleContent {
    @State private var name = ""
    @State private var note = ""
    @State private var said = ""

    /// The field the two buttons reach - declared with `@Aim`, which is what
    /// an act needs and what a render cannot take away.
    @Aim(Entry.self) private var first

    /// The page this sample is on - MAUI gives the tap-to-close to the PAGE.
    @Environment private var page: PageSession

    static let id = "keyboard"
    static let title = "Keyboard"
    static let summary = "Three ways to give the keyboard back, and MAUI wrote two of them."

    static let code = """
        @State private var name = ""
        @State private var note = ""
        @State private var said = ""

        @Aim(Entry.self) private var first

        @Environment private var page: PageSession

        var content: any View {
            VStack {
                // `said` is read here, so the answer builds this closure.
                DebugInfoLabel()

                Entry($name)
                    .placeholder("Tap here, then tap the page beside it")
                    .aim(first)

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
            // MAUI gives this to the PAGE, so it is written into the page's
            // session - where a search box goes too.
            .onCreated { page.hideSoftInputOnTapped = true }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Entry($name)
                .automationId("keyboard.name")
                .semanticDescription("Name")
                .placeholder("Tap here, then tap the page beside it")
                .aim(first)

            Entry($note)
                .automationId("keyboard.note")
                .semanticDescription("Note")
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
        // The property this sample is half about - the PAGE's. MAUI
        // recognizes the tap ALONGSIDE everything else, which is why this
        // page still scrolls.
        .onCreated { page.hideSoftInputOnTapped = true }
    }

    var notes: Element? {
        VStack {
            Label("TAPPING BESIDE A FIELD closes the keyboard, because the page's session says "
                + "`hideSoftInputOnTapped`. It is MAUI's own property, and MAUI recognizes "
                + "that tap alongside everything else - so this page still scrolls, and "
                + "both buttons still answer, which a view laid over the content to catch "
                + "touches could not promise.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A BUTTON THAT KNOWS THE FIELD says so: `.unfocus()` on the field's "
                + "aim - `.aim(first)` puts the field in it, and the act is aimed at that "
                + "control.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A BUTTON THAT DOES NOT asks instead: `SoftInput.hide()` names no view, "
                + "because which control the reader touched last is not something this side "
                + "knows. The host asks the page, and answers whether anything was focused.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON A DESKTOP THE ANSWER IS THE PLATFORM'S rather than this act's, "
                + "and the two desktops disagree: on Windows a clicked button TAKES the "
                + "focus, so by the time the handler asks, the button just pressed is "
                + "what holds it and the answer is always yes; on a Mac a button takes "
                + "no focus and the field has already given it up, so the answer is "
                + "always no. The act still unfocuses whatever the page has - but the "
                + "wording above is a phone's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It reaches the navigation bar's search box too: on iOS unfocusing that "
                + "box is what gives the bar, and its back button, back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
