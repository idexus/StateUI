import StateUI

/// MAUI: RefreshView.
struct RefreshViewSample: SampleContent {
    @State private var refreshing = false
    @State private var enabled = true
    @State private var readings = ["Reading 3", "Reading 2", "Reading 1"]
    @State private var next = 4

    /// WHERE A PULL CAN ACTUALLY BE MADE: a finger on iOS and Android, and a
    /// mouse drag on Mac Catalyst. Everywhere else the platform draws the pull
    /// with a control that answers touch and pen alone, so no gesture a mouse
    /// can make starts one - and this sample would be a paragraph about
    /// something the reader cannot try.
    @Environment private var device: DeviceInfo

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

        // A pull is a finger's, so the sample asks which platform this is.
        @Environment private var device: DeviceInfo

        private var pulls: Bool {
            ["iOS", "Android", "MacCatalyst"].contains(device.platform)
        }

        // The pull area takes the STAR row, so it fills whatever the switch
        // below it leaves - a pull needs somewhere to pull.
        Grid {
            RefreshView($refreshing) {
                ScrollView {
                    VStack {
                        // INSIDE these braces, because that is where
                        // `readings` is read: a pull adds a reading, so the
                        // work a pull asks for is what builds this closure.
                        DebugInfoLabel()

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
                // Nothing else clears it: the pull sets it, and the work is
                // what says it is over.
                refill()
            }

            HStack {
                Label("Pull enabled")

                // A SWITCH ABOUT A GESTURE THE PLATFORM CANNOT MAKE offers a
                // choice that changes nothing, so where there is no pull it
                // reads off - the flag is put there as the page loads - and
                // refuses to be flipped.
                Switch($enabled)
                    .isEnabled(pulls)

                // WHERE THE PLATFORM HAS NO PULL, the app needs another way
                // in - and it is the one a desktop app writes: set the flag,
                // do the work, clear it.
                if !pulls {
                    Button("Refresh now").onClicked {
                        refreshing = true

                        // Some platforms ask for the work themselves once the
                        // flag is set, so this finishes the job only where
                        // nothing else did - the flag says which.
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))

                            if refreshing { refill() }
                        }
                    }
                }
            }
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .onLoaded {
            // A STATE'S OWN DEFAULT CANNOT ASK WHAT PLATFORM THIS IS - it is
            // worked out where the view is built, before anything is around to
            // answer - so the flag is put right as the page loads.
            if !pulls { enabled = false }
        }

        // What a refresh DOES, wherever it was asked for.
        private func refill() {
            readings.insert("Reading \\(next)", at: 0)
            next += 1
            refreshing = false
        }
        """

    var content: Element {
        Grid {
            RefreshView($refreshing) {
                ScrollView {
                    VStack {
                        // INSIDE these braces, because that is where
                        // `readings` is read: a pull adds a reading, so the
                        // work a pull asks for is what builds this closure.
                        DebugInfoLabel()

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
                // Nothing else clears it. MAUI shows the spinner for as long as
                // IsRefreshing is true, and the work is what says it is over.
                refill()
            }

            HStack {
                Label("Pull enabled")
                    .fontSize(13)
                    .textColor(pulls ? Palette.text : Palette.subtle)
                    .verticalOptions(.center)

                // A SWITCH ABOUT A GESTURE THE PLATFORM CANNOT MAKE offers a
                // choice that changes nothing, so where there is no pull it
                // reads off - the flag is put there as the page loads - and
                // refuses to be flipped.
                Switch($enabled)
                    .automationId("refreshView.enabled")
                    .semanticDescription("Pull to refresh")
                    .isEnabled(pulls)

                // A PULL IS A FINGER'S, so a machine with a mouse needs
                // another way in - and it is the one a desktop app writes:
                // set the flag, do the work, clear it. A write made in Swift
                // raises no handler, so this cannot lean on .onRefreshing.
                if !pulls {
                    Button("Refresh now").onClicked {
                        refreshing = true

                        // WINDOWS ASKS FOR THE WORK ITSELF once the flag is
                        // set - its own refresh control raises the handler,
                        // measured - so this finishes the job only where
                        // nothing else did, and the flag is what says which.
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))

                            if refreshing { refill() }
                        }
                    }
                    .fontSize(13)
                }
            }
            .spacing(10)
            .horizontalOptions(.center)
            .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(12)
        .onLoaded {
            // A STATE'S OWN DEFAULT CANNOT ASK WHAT PLATFORM THIS IS - it is
            // worked out where the view is built, before anything is around to
            // answer - so the flag is put right as the page loads: on where a
            // pull can be made, off where the platform has none.
            if !pulls { enabled = false }
        }
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

            Label("A PULL NEEDS A FINGER ON WINDOWS AND ON LINUX: the platform draws it "
                + "with a control that answers touch and pen alone, so a mouse cannot "
                + "start one - and that is where the button above appears. It is what a "
                + "desktop app writes anyway: set the flag, do the work, clear it. On iOS, "
                + "Android and Mac Catalyst the pull itself works and there is no button - "
                + "and where there is none the switch beside it reads off and is refused, "
                + "a choice about a gesture nobody can make being no choice at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// Whether this platform's own pull can be made at all - see `device`.
    private var pulls: Bool {
        ["iOS", "Android", "MacCatalyst"].contains(device.platform)
    }

    /// What a refresh DOES, wherever it was asked for - the pull's handler runs
    /// it, and so does the button.
    private func refill() {
        readings.insert("Reading \(next)", at: 0)
        next += 1
        refreshing = false
    }
}
