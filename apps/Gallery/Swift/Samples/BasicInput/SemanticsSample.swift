import StateUI

/// MAUI: SemanticProperties, and Element.AutomationId.
struct SemanticsSample: SampleContent {
    @State private var described = true

    @State private var taps = 0

    static let id = "semantics"
    static let title = "Semantics"
    static let summary = "What a view says about itself - to a reader who cannot see it, and to whatever drives the app from outside."

    /// Said once, and both written onto the button and printed under it - so
    /// what the sample shows cannot drift from what the platform was handed.
    private static let says = "Add to favourites"

    private static let hint = "Puts this item on your list"

    static let code = """
        @State private var described = true
        @State private var taps = 0

        // What a reader is told is read here, so throwing the switch builds
        // this closure again.
        VStack {
            DebugInfoLabel()

            HStack {
                // A picture and nothing else. To anybody not looking at it,
                // this control has no name at all.
                ImageButton(light: "nav_media.png", dark: "nav_media_dark.png")
                    .automationId("semantics.bare")
                    .onClicked { taps += 1 }

                // The same button, saying what it is and what using it does.
                // Written as a value rather than in the chain, so throwing the
                // switch CLEARS the property off the same control instead of
                // building a different one.
                describedButton
            }

            Label("Tapped \\(taps) time\\(taps == 1 ? "" : "s")")

            SwitchRow("Describe the second button", $described)
        }

        private var describedButton: Element {
            let button = ImageButton(light: "nav_layout.png", dark: "nav_layout_dark.png")
                .automationId("semantics.described")
                .onClicked { taps += 1 }

            return described
                ? button.semanticDescription("Add to favourites")
                    .semanticHint("Puts this item on your list")
                : button
        }

        // Said out loud, now, whatever the reader was on. An ACT, because it
        // is something that happens at a moment rather than a value a view
        // can hold.
        Button("Announce the count")
            .onClicked {
                try await SemanticScreenReader.announce(
                    "Tapped \\(taps) time\\(taps == 1 ? "" : "s")")
            }

        // One word takes the panel AND everything in it out of what a screen
        // reader walks; the rule below is a single view taken out.
        Border {
            VStack {
                Label("Skipped")
                Label("Neither line is read")
            }
        }
        .automationExcludedWithChildren(true)

        BoxView(Palette.outline)
            .heightRequest(1)
            .automationIsInAccessibleTree(false)
        """

    var content: Element {
        VStack {
            DebugInfoLabel()

            HStack {
                VStack {
                    ImageButton(light: "nav_media.png", dark: "nav_media_dark.png")
                        .automationId("semantics.bare")
                        .aspect(.aspectFit)
                        .widthRequest(64)
                        .heightRequest(64)
                        .borderColor(Palette.outline)
                        .borderWidth(1)
                        .cornerRadius(12)
                        .onClicked { taps += 1 }

                    Label("A reader hears")
                        .fontSize(11)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    Label("nothing")
                        .fontSize(13)
                        .fontAttributes(.italic)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
                .widthRequest(150)

                VStack {
                    describedButton

                    Label("A reader hears")
                        .fontSize(11)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)

                    Label(described ? "\(Self.says)\n\(Self.hint)" : "nothing")
                        .fontSize(13)
                        .fontAttributes(described ? .none : .italic)
                        .textColor(described ? Palette.accent : Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
                .widthRequest(150)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("Tapped \(taps) time\(taps == 1 ? "" : "s")")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            SwitchRow("Describe the second button", $described)
                .horizontalOptions(.center)

            SectionTitle("A heading is what this says it is")

            // Drawn alike and read differently: only the second is somewhere a
            // reader jumping through the page can land.
            VStack {
                Label("Drawn large")
                    .fontSize(20)
                    .fontAttributes(.bold)

                Label("A heading, and drawn the same")
                    .fontSize(20)
                    .fontAttributes(.bold)
                    .semanticHeadingLevel(.level1)
            }
            .spacing(4)

            SectionTitle("SAID OUT LOUD")

            Button("Announce the count")
                .automationId("semantics.announce")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked {
                    try await SemanticScreenReader.announce(
                        "Tapped \(taps) time\(taps == 1 ? "" : "s")")
                }

            SectionTitle("WHAT A READER WALKS PAST")

            HStack {
                Border {
                    VStack {
                        Label("Walked")
                            .fontSize(15)
                            .fontAttributes(.bold)

                        Label("Both lines are read")
                            .fontSize(12)
                            .textColor(Palette.subtle)
                    }
                    .spacing(2)
                    .padding(12)
                }

                // The whole panel, and everything in it, is not there at all
                // to a screen reader - one word instead of one per view.
                Border {
                    VStack {
                        Label("Skipped")
                            .fontSize(15)
                            .fontAttributes(.bold)

                        Label("Neither line is read")
                            .fontSize(12)
                            .textColor(Palette.subtle)
                    }
                    .spacing(2)
                    .padding(12)
                }
                .automationExcludedWithChildren(true)
            }
            .spacing(12)
            .horizontalOptions(.center)

            // A rule is decoration: a stop that would waste the reader's time.
            BoxView(Palette.outline)
                .heightRequest(1)
                .automationIsInAccessibleTree(false)
        }
        .spacing(12)
    }

    /// The described button, built as a VALUE so that turning the switch off
    /// takes the property off THIS control rather than describing another one.
    /// An absent property is cleared back to MAUI's own default, which is what
    /// makes a modifier written under a condition cost the property and not
    /// the control.
    private var describedButton: Element {
        let button = ImageButton(light: "nav_layout.png", dark: "nav_layout_dark.png")
            .automationId("semantics.described")
            .aspect(.aspectFit)
            .widthRequest(64)
            .heightRequest(64)
            .borderColor(Palette.outline)
            .borderWidth(1)
            .cornerRadius(12)
            .onClicked { taps += 1 }

        return described
            ? button.semanticDescription(Self.says).semanticHint(Self.hint)
            : button
    }

    var notes: Element? {
        VStack {
            Label("Two jobs, four modifiers, and they do not stand in for one another. "
                + "`.semanticDescription` and `.semanticHint` are what a screen reader "
                + "SAYS: the first names the control, the second says what using it does. "
                + "`.semanticHeadingLevel` marks a view as a heading, which is how a "
                + "reader moves through a long page. `.automationId` is a handle nobody "
                + "hears - it is what a UI test, a script or an agent driving the "
                + "application asks the platform to find.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Every control on this page carries one: the two buttons answer to "
                + "`semantics.bare` and `semantics.described`. An id is worth having "
                + "wherever something outside the application has to find a control, and "
                + "it has to stay the same between renders - one that moves with the "
                + "state is one nothing can wait for.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Turn the switch off and the description is taken off the control it "
                + "was on, rather than a second button being drawn: a property that goes "
                + "away is named on the wire and cleared back to MAUI's default. To hear "
                + "any of it, turn on the platform's screen reader - VoiceOver on Apple, "
                + "TalkBack on Android, Narrator on Windows - and touch the two buttons "
                + "in turn.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
