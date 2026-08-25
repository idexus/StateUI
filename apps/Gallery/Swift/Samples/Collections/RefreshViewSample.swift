import StateUI

/// MAUI: RefreshView.
struct RefreshViewSample: SampleContent {
    @State private var refreshing = false
    @State private var enabled = true
    @State private var readings = ["Reading 3", "Reading 2", "Reading 1"]
    @State private var next = 4

    static let id = "refreshView"
    static let title = "RefreshView"
    static let summary = "Pull down on a list to ask for it again - and clear the flag when the work is done."

    /// Held still, and for the reason a gesture sample is: a pull is a drag, and
    /// a ScrollView above this one would claim it before the RefreshView heard
    /// about it.
    static let scrolls = false
    static let fills = true

    static let code = """
        @State private var refreshing = false
        @State private var enabled = true
        @State private var readings = ["Reading 3", "Reading 2", "Reading 1"]
        @State private var next = 4

        // The pull area takes the STAR row, so it fills whatever the switch
        // below it leaves - a pull needs somewhere to pull.
        Grid {
            RefreshView($refreshing) {
                ScrollView {
                    VStack {
                        ForEach(readings) { reading in
                            Label(reading)
                                .padding(12, 10)
                                .id(reading)
                        }
                    }
                }
            }
            .isRefreshEnabled(enabled)
            .gridRow(0)
            .onRefreshing {
                readings.insert("Reading \\(next)", at: 0)
                next += 1

                // Nothing else clears it: the pull sets it, the handler is
                // what says the work is over.
                refreshing = false
            }

            HStack {
                Label("Pull enabled")

                Switch($enabled)
            }
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        """

    var content: Element {
        Grid {
            RefreshView($refreshing) {
                ScrollView {
                    VStack {
                        ForEach(readings) { reading in
                            Label(reading)
                                .fontSize(14)
                                .padding(12, 10)
                                .id(reading)
                        }
                    }
                }
            }
            .isRefreshEnabled(enabled)
            .refreshColor(Palette.accent)
            .gridRow(0)
            .onRefreshing {
                readings.insert("Reading \(next)", at: 0)
                next += 1

                // Nothing else clears it. MAUI shows the spinner for as long as
                // IsRefreshing is true, and the pull is the only thing that sets
                // it - which is the whole contract.
                refreshing = false
            }

            HStack {
                Label("Pull enabled")
                    .fontSize(13)
                    .verticalOptions(.center)

                Switch($enabled)
            }
            .spacing(10)
            .horizontalOptions(.center)
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("It goes AROUND the scroller rather than inside one: MAUI's RefreshView "
                + "holds a single scrollable view, and a pull is a gesture that scroller "
                + "would otherwise claim.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("isRefreshing is written from both sides: the pull sets it, and "
                + "clearing it in the handler is what ends the spinner - nothing else "
                + "does.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("ON WINDOWS A PULL NEEDS A FINGER: the pull is a touch gesture "
                + "there, so a mouse cannot start one. `isRefreshing` still works, so a "
                + "desktop app gives the same handler a button and sets it itself.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
