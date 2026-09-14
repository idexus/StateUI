import StateUI

/// A list pulled down to ask for it again, and the flag the work clears.
struct RefreshViewSample: SampleContent, ExampleContent {
    @State private var refreshing = false
    @State private var enabled = true
    @State private var readings = ["Reading 3", "Reading 2", "Reading 1"]
    @State private var next = 4

    /// What kind of device this is. The sample offers a pull where a finger
    /// can make one - a phone or a tablet - and a button everywhere else,
    /// rather than a paragraph about something the reader cannot try.
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

        // Not every device can make a pull, so the sample asks which kind
        // this is.
        @Environment private var device: DeviceInfo

        private var pulls: Bool {
            device.idiom == .phone || device.idiom == .tablet
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
                // reads off - the flag is put there as the view is created - and
                // refuses to be flipped.
                Switch($enabled)
                    .isEnabled(pulls)

                // WHERE THE PLATFORM HAS NO PULL, the app needs another way
                // in - and it is the one a desktop app writes: set the flag,
                // do the work, clear it.
                if !pulls {
                    Button("Refresh now").onClicked {
                        refreshing = true

                        // Only if the flag is still set: whatever cleared it
                        // in the meantime has done the work already.
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))

                            if refreshing { refill() }
                        }
                    }
                }
            }
            .gridRow(1)
        }
        .rows(.fill, .auto)
        .onCreated {
            // A STATE'S OWN DEFAULT CANNOT ASK WHAT PLATFORM THIS IS - it is
            // worked out where the view is built, before anything is around to
            // answer - so the flag is put right as the view is created.
            if !pulls { enabled = false }
        }

        // What a refresh DOES, wherever it was asked for.
        private func refill() {
            readings.insert("Reading \\(next)", at: 0)
            next += 1
            refreshing = false
        }
        """

    var content: any View {
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
                // Nothing else clears it: the spinner shows for as long as the
                // flag is true, and the work is what says it is over.
                refill()
            }

            HStack {
                Label("Pull enabled")
                    .fontSize(13)
                    .textColor(pulls ? Palette.text : Palette.subtle)
                    .verticalAlignment(.center)

                // A SWITCH ABOUT A GESTURE THE PLATFORM CANNOT MAKE offers a
                // choice that changes nothing, so where there is no pull it
                // reads off - the flag is put there as the view is created - and
                // refuses to be flipped.
                Switch($enabled)
                    .automationId("refreshView.enabled")
                    .semanticDescription("Pull to refresh")
                    .isEnabled(pulls)

                // WHERE THE PLATFORM HAS NO PULL, a mouse needs another way
                // in - and it is the one a desktop app writes: set the flag,
                // do the work, clear it. A write made in Swift raises no
                // handler, so this cannot lean on .onRefreshing.
                if !pulls {
                    Button("Refresh now").onClicked {
                        refreshing = true

                        // Only if the flag is still set: whatever cleared it
                        // in the meantime has done the work already.
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))

                            if refreshing { refill() }
                        }
                    }
                    .fontSize(13)
                }
            }
            .spacing(10)
            .horizontalAlignment(.center)
            .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(12)
        .onCreated {
            // A STATE'S OWN DEFAULT CANNOT ASK WHAT PLATFORM THIS IS - it is
            // worked out where the view is built, before anything is around to
            // answer - so the flag is put right as the view is created: on where a
            // pull can be made, off where the platform has none.
            if !pulls { enabled = false }
        }
    }

    var notes: Element? {
        VStack {
            Label("It goes AROUND the scroller rather than inside one: a pull is a "
                + "gesture that scroller would otherwise claim.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`isRefreshing` is written from both sides: the pull sets it, and "
                + "clearing it in the handler is what ends the spinner - nothing else "
                + "does.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Where this sample offers no pull, the button beside the switch does "
                + "what a desktop app writes anyway: set the flag, do the work, clear it. "
                + "A write made in Swift raises no handler, so the button runs the work "
                + "itself rather than waiting for `.onRefreshing`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("And there the switch reads off and refuses to be flipped: a choice "
                + "about a gesture nobody can make is no choice at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// Whether this sample offers a pull here - see `device`.
    private var pulls: Bool {
        device.idiom == .phone || device.idiom == .tablet
    }

    /// What a refresh DOES, wherever it was asked for - the pull's handler runs
    /// it, and so does the button.
    private func refill() {
        readings.insert("Reading \(next)", at: 0)
        next += 1
        refreshing = false
    }
}
