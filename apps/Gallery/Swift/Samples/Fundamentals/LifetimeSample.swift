import StateUI

/// `.onCreated` and `.onDestroying`: what runs as an element comes into the
/// tree and as it leaves, once each.
struct LifetimeSample: SampleContent {
    /// Whether the card is in the tree at all.
    @State private var shown = true

    /// The card's identity - a new one is a new card.
    @State private var identity = 1

    /// How often the page was built again on purpose, which carries the card,
    /// built with the same inputs, and creates nothing.
    @State private var builds = 0

    /// What the cards have said, oldest first.
    @State private var log: [String] = []

    static let id = "lifetime"
    static let title = "Element lifetime"
    static let summary = "What runs as a view comes into the tree and as it leaves - "
        + "once each, with its state still there to read."

    static let code = """
        @State private var shown = true
        @State private var identity = 1
        @State private var builds = 0
        @State private var log: [String] = []

        VStack {
            // Every button builds this closure again. Build this again changes
            // nothing the card is built with, so it carries the card and
            // creates nothing.
            DebugInfoLabel()

            SwitchRow("Show the card", $shown)

            HStack {
                Button("A new card").onClicked { identity += 1 }
                Button("Build this again · \\(builds)").onClicked { builds += 1 }
            }

            if shown {
                // A new identity is a new card: the one on screen is
                // destroyed, and this one created.
                LifetimeCard(number: identity, log: $log)
                    .id(identity)
            }

            VStack {
                if log.isEmpty {
                    Label("nothing yet")
                }

                ForEach(Array(log.suffix(6))) { line in
                    Label(line)
                }
            }
        }

        struct LifetimeCard: ContentView {
            let number: Int
            @Binding var log: [String]
            @State private var taps = 0

            var content: any View {
                Button("Card \\(number) · tapped \\(taps)")
                    .onClicked { taps += 1 }
                    // Once, after the render that brings the card in - its
                    // state and its environment are there to use.
                    .onCreated {
                        log.append("\\(log.count + 1) · card \\(number) created")
                    }
                    // Once, after the render that leaves it out - and its
                    // state still answers, which is what saving needs.
                    .onDestroying {
                        log.append("\\(log.count + 1) · card \\(number) destroying, tapped \\(taps)")
                    }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            SwitchRow("Show the card", $shown)

            HStack {
                Button("A new card")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { identity += 1 }

                Button("Build this again · \(builds)")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { builds += 1 }
            }
            .spacing(10)

            if shown {
                LifetimeCard(number: identity, log: $log)
                    .id(identity)
            }

            VStack {
                if log.isEmpty {
                    Label("nothing yet")
                        .fontSize(14)
                        .textColor(Palette.subtle)
                }

                ForEach(Array(log.suffix(6))) { line in
                    Label(line)
                        .fontSize(14)
                        .fontFamily("Menlo")
                }
            }
            .spacing(4)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Switch the card off and on: it is destroyed and created again - a new "
                + "card, counting from nought. A new card does the same to the one on "
                + "screen by giving it a new identity. Build this again builds the page "
                + "once more, which carries the card, built with the same inputs, and "
                + "creates nothing: an element is created once, however many times the "
                + "view around it is built.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Tap the card before it goes: what it says as it is destroyed is its "
                + "own count, because its state still answers - the place to save what it "
                + "holds. Both are on every view and control and on the pages the library "
                + "builds - a page of your own writes them on its content - and both run "
                + "after the render that made the change.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// A card that says when it comes and goes, counting its own taps.
private struct LifetimeCard: ContentView {
    let number: Int
    @Binding var log: [String]
    @State private var taps = 0

    var content: any View {
        Button("Card \(number) · tapped \(taps)")
            .fontSize(15)
            .textColor(.white)
            .backgroundColor(Palette.accent)
            .cornerRadius(10)
            .padding(20, 12)
            .horizontalOptions(.center)
            .onClicked { taps += 1 }
            .onCreated {
                log.append("\(log.count + 1) · card \(number) created")
            }
            .onDestroying {
                log.append("\(log.count + 1) · card \(number) destroying, tapped \(taps)")
            }
    }
}
