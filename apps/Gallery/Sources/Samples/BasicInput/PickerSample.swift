import StateUI

/// One choice out of a list, opened by the user or by a button.
struct PickerSample: SampleContent, ExampleContent {
    // listing: PickerSample
    @State private var size = 1
    @State private var changes = 0
    @State private var opened = 0
    @State private var showing = false
    // listing: end

    static let id = "picker"
    static let title = "Picker"
    static let summary = "One choice out of a list, with the chosen index as a binding."

    // listing: PickerSample
    static let sizes = ["Small", "Medium", "Large"]

    var body: some View {
        VStack {
            // The choice and the two counts are read here, so a pick builds
            // this closure - and a write of OURS raises no event at all.
            DebugInfoLabel()

            Picker(Self.sizes)
                .accessibilityIdentifier("picker.size")
                .accessibilityLabel("Size")
                .onSelectedIndexChanged { _ in changes += 1 }
                .selectedIndex($size)
                .placeholder("Size")
                // Settable, so a button elsewhere can open the list. The two
                // events answer the user and the platform - never this
                // side's own write.
                .isOpen(showing)
                .onOpened { opened += 1; showing = true }
                .onClosed { showing = false }

            Button("Open the list")
                .onClicked { showing = true }
                .horizontalAlignment(.center)

            Text(chosen)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Text("Changed \(changes)x, opened \(opened)x")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The items are a list of strings and the choice is an index into it; "
                + "-1 means nothing is chosen.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`$size` and the handler both hear the user's choice: the binding lands "
                + "the index on the state, and an `.onSelectedIndexChanged` written beside "
                + "it runs after it has landed - whichever order the two are written in.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`isOpen` is settable, so the button opens the list without touching "
                + "it. The platform closes it on its own - a tap outside, a choice made - "
                + "which is why `onClosed` writes the state back rather than the state "
                + "being trusted.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("THE COUNT ONLY MOVES FOR A USER. Opening the list with the button "
                + "leaves `opened` where it was: that open is this side's own write, and "
                + "a write made here never comes back as an event. Tap the field itself "
                + "and the count goes up.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: PickerSample
    private var chosen: String {
        size >= 0 && size < Self.sizes.count ? "Chosen: \(Self.sizes[size])" : "Nothing chosen"
    }
    // listing: end
}
