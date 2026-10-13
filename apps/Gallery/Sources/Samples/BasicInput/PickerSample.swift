import StateUI

/// One value chosen out of a list - offered as a menu, as segments or as radio buttons - opened by the user or by a
/// button.
struct PickerSample: SampleContent, ExampleContent {
    // listing: PickerSample
    /// The values on offer.
    enum Size: CaseIterable, Equatable {
        case small, medium, large
    }

    /// The value chosen, nil while none is.
    @State private var size: Size? = .medium
    @State private var opened = 0
    @State private var showing = false
    // listing: end

    static let id = "picker"
    static let title = "Picker"
    static let summary = "One value chosen out of a list, as a menu, as segments or as radio buttons."

    // listing: PickerSample
    var body: some View {
        VStack {
            // The choice and the count are read here, so a pick builds this
            // closure - and a write of OURS raises no event at all.
            DebugInfoLabel()

            Picker(Size.allCases, selection: $size) { "\($0)".capitalized }
                .accessibilityIdentifier("picker.size")
                .accessibilityLabel("Size")
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

            // The same choice, offered as segments and as radio buttons.
            Picker(Size.allCases, selection: $size) { "\($0)".capitalized }
                .accessibilityIdentifier("picker.segments")
                .accessibilityLabel("Size as segments")
                .presentation(.segmented)

            Picker(Size.allCases, selection: $size) { "\($0)".capitalized }
                .accessibilityIdentifier("picker.radio")
                .accessibilityLabel("Size as radio buttons")
                .presentation(.radio)

            Text(size.map { "Chosen: \($0)" } ?? "Nothing chosen")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Text("Opened \(opened)x")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The choice is one of the values, not a place in the list: "
                + "nil while nothing is chosen, and the same value however the list is ordered.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The three pickers share one state: choose in any and the others follow.")
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
}
