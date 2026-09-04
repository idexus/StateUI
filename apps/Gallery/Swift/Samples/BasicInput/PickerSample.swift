import StateUI

/// MAUI: Picker.
struct PickerSample: SampleContent {
    @State private var size = 1
    @State private var changes = 0
    @State private var opened = 0
    @State private var showing = false

    static let id = "picker"
    static let title = "Picker"
    static let summary = "One choice out of a list, with the chosen index as a binding."

    static let sizes = ["Small", "Medium", "Large"]

    static let code = """
        @State private var size = 1
        @State private var changes = 0
        @State private var opened = 0
        @State private var showing = false

        static let sizes = ["Small", "Medium", "Large"]

        VStack {
            Picker(Self.sizes)
                .onSelectedIndexChanged { _ in changes += 1 }
                .selectedIndex($size)
                .title("Size")
                // Settable, so a button elsewhere can open the list - and
                // the two events answer whoever opened it, reader or
                // platform.
                .isOpen(showing)
                .onOpened { opened += 1; showing = true }
                .onClosed { showing = false }

            Button("Open the list").onClicked { showing = true }

            Label(chosen)
            Label("Changed \\(changes)x, opened \\(opened)x")
        }

        /// -1 is MAUI's "nothing chosen", so it is worth saying out loud.
        private var chosen: String {
            size >= 0 && size < Self.sizes.count
                ? "Chosen: \\(Self.sizes[size])"
                : "Nothing chosen"
        }
        """

    var example: Element {
        VStack {
            Picker(Self.sizes)
                .onSelectedIndexChanged { _ in changes += 1 }
                .selectedIndex($size)
                .title("Size")
                .isOpen(showing)
                .onOpened { opened += 1; showing = true }
                .onClosed { showing = false }

            Button("Open the list")
                .onClicked { showing = true }
                .horizontalOptions(.center)

            Label(chosen)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label("Changed \(changes)x, opened \(opened)x")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The items are a list of strings and the choice is an index, which is "
                + "what MAUI's Picker holds. -1 means nothing is chosen.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`$size` and the handler are one event written twice: the binding sets "
                + "the index and registers the write-back, and an `.onSelectedIndexChanged` "
                + "written beside it still runs - whichever order the two are written in.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`isOpen` is settable, so the button opens the list without touching "
                + "it. The platform closes it on its own - a tap outside, a choice made - "
                + "which is why `onClosed` writes the state back rather than the state "
                + "being trusted.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    private var chosen: String {
        size >= 0 && size < Self.sizes.count ? "Chosen: \(Self.sizes[size])" : "Nothing chosen"
    }
}
