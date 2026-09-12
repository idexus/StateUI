import StateUI

/// THE TWO LAYERS OF REACTIVITY, named and then measured.
///
/// Layer one is a GET: `Label("Counter \(counter)")` reads the value, which
/// makes the closure it is written in a reader, and a write builds that
/// closure again. Layer two is a CHANNEL: `Label($counter.convert { … })`
/// hands the state on, the host writes the words on its own frames, and
/// nothing is built at all. The second example puts microseconds on both.
struct TwoLayersSample: SampleContent {
    static let id = "two-layers"
    static let title = "Two layers of reactivity"
    static let summary = "A value READ rebuilds the closure that read it; the same value as a "
        + "CHANNEL rebuilds nobody - and the second example says what each costs, in microseconds."

    static let code = """
        // -- TWO LAYERS --

        @State private var counter = 0

        VStack {
            // Neither the button nor this closure reads the count: a handler
            // reads when it FIRES, not at build. So this stands at one build.
            DebugInfoLabel()

            Button("+1").onClicked { counter += 1 }

            // LAYER ONE - A GET. The value is read here, so this closure is
            // its reader and every press builds it again.
            VStack {
                Label("Counter \\(counter)")
                DebugInfoLabel()                    // climbs, "for counter"
            }

            // LAYER TWO - A CHANNEL. The state is handed on, the host writes
            // the words as it changes, and this closure is never built again.
            VStack {
                Label($counter.convert { "Counter \\($0)" })
                DebugInfoLabel()                    // stays at one
            }
        }

        // -- WHAT IT COSTS --

        @State private var counter = 0
        @State private var leaves = 100

        // The same two layers inside a subtree worth describing: `leaves`
        // little views, plus the counter. Each side times its OWN describe -
        // the clock is read at the top of the closure and again at the
        // bottom - so the number is what that press cost in Swift.
        VStack {
            HStack {
                Button("+1").onClicked { counter += 1 }

                // A choice of more than two, so a button that cycles them.
                Button("Views: \\(leaves)")
                    .onClicked { leaves = leaves == 25 ? 100 : leaves == 100 ? 400 : 25 }
            }

            // LAYER ONE: the get is in the closure, so a press describes every
            // leaf again and the reading below says how long that took.
            FlexLayout {
                let began = ContinuousClock.now

                ForEach(Array(0 ..< leaves), id: \\.self) { _ in
                    BoxView().widthRequest(7).heightRequest(7)
                }

                Label("Counter \\(counter)")

                Label(took(began, leaves))
                DebugInfoLabel()                    // climbs on every press
            }

            // LAYER TWO: the same subtree, the counter handed on as a channel.
            // A press describes nothing here - the number below is what its ONE
            // build cost, and it stands still however often you press.
            FlexLayout {
                let began = ContinuousClock.now

                ForEach(Array(0 ..< leaves), id: \\.self) { _ in
                    BoxView().widthRequest(7).heightRequest(7)
                }

                Label($counter.convert { "Counter \\($0)" })

                Label(took(began, leaves))
                DebugInfoLabel()                    // stays at one
            }
        }

        /// How long describing a closure has taken so far, in microseconds -
        /// read at its top and printed at its bottom.
        private func took(_ began: ContinuousClock.Instant, _ views: Int) -> String {
            let spent = ContinuousClock.now - began
            let parts = spent.components
            let nanoseconds = parts.seconds * 1_000_000_000 + parts.attoseconds / 1_000_000_000

            return "\\(views) views described in \\(microseconds(nanoseconds)) µs, "
        }

        /// Nanoseconds as microseconds, to one decimal - written by hand, a
        /// formatter being Foundation's.
        private func microseconds(_ nanoseconds: Int64) -> String {
            let tenths = (nanoseconds + 50) / 100

            return "\\(tenths / 10).\\(tenths % 10)"
        }
        """

    var parts: [SamplePart] {
        let layers = LayerRows()
        let cost = LayerCost()

        return [
            SamplePart(title: "TWO LAYERS", view: layers, notes: layers.words),
            SamplePart(title: "WHAT IT COSTS", view: cost, notes: cost.words),
        ]
    }

    var content: any View {
        LayerRows()
    }
}

/// The two layers side by side, each in a closure of its own so its build
/// count is its own.
private struct LayerRows: ContentView {
    /// The one value both rows show - held here, where it is shown.
    @State private var counter = 0

    var content: any View {
        VStack {
            // Nothing here reads the count - a handler reads when it fires -
            // so this closure stands at one build however often you press.
            DebugInfoLabel()

            Button("+1")
                .fontSize(14)
                .backgroundColor(Palette.accent)
                .textColor(Palette.onAccent)
                .cornerRadius(8)
                .padding(22, 10)
                .horizontalOptions(.center)
                .onClicked { counter += 1 }

            boxed("LAYER ONE · a get - Label(\"Counter \\(counter)\")") {
                Label("Counter \(counter)")
                    .fontSize(20)
                    .fontAttributes(.bold)
                DebugInfoLabel()
            }

            boxed("LAYER TWO · a channel - Label($counter.convert { … })") {
                Label($counter.convert { "Counter \($0)" })
                    .fontSize(20)
                    .fontAttributes(.bold)
                DebugInfoLabel()
            }
        }
        .spacing(12)
    }

    var words: any View {
        VStack {
            Label("Both rows show the same number and they cost different things. The "
                + "first READS it, which makes that row's closure a reader: every press "
                + "builds the row again, compares it and sends what changed. The second "
                + "hands the state on, and the host writes the words on its own frames - "
                + "so the row is built once and never again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A conversion is what makes the channel say more than a bare number: "
                + "`$counter.convert { \"Counter \\($0)\" }` is a second value the host "
                + "carries, worked out by an engine the differ writes. Press +1 and watch "
                + "the two readings part company.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }

    /// One captioned row, its content in a closure of its own - which is what
    /// makes the reading inside it that row's alone.
    private func boxed(_ caption: String, @ViewBuilder _ content: @escaping () -> [Element]) -> any View {
        Border {
            VStack {
                Label(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
        .stroke(Palette.outline)
    }
}

/// The same two layers over a subtree worth describing, each side timing its
/// own describe - which is the comparison in microseconds.
private struct LayerCost: ContentView {
    /// The value the two blocks show, one reading it and one handed it.
    @State private var counter = 0

    /// How many views stand in each block - the thing a rebuild describes.
    @State private var leaves = 100

    var content: any View {
        VStack {
            HStack {
                Button("+1")
                    .fontSize(13)
                    .backgroundColor(Palette.accent)
                    .textColor(Palette.onAccent)
                    .cornerRadius(8)
                    .padding(18, 8)
                    .onClicked { counter += 1 }

                // A choice of more than two, so a button that cycles them.
                Button("Views: \(leaves)")
                    .fontSize(13)
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(18, 8)
                    .onClicked { leaves = leaves == 25 ? 100 : leaves == 100 ? 400 : 25 }
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label("LAYER ONE · the counter is READ in the block below")
                .fontSize(11)
                .textColor(Palette.subtle)

            Described(counter: $counter, leaves: leaves)

            Label("LAYER TWO · the same block, the counter handed on as a channel")
                .fontSize(11)
                .textColor(Palette.subtle)

            Channelled(counter: $counter, leaves: leaves)
        }
        .spacing(8)
    }

    var words: any View {
        VStack {
            Label("Two blocks of the same views, one number shown two ways. Each block "
                + "reads the clock at the top of its own closure and again at the bottom, "
                + "so what it prints is what describing it cost this time round.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Press +1. The first block is described again - every leaf of it - and "
                + "its build count and its microseconds both climb. The second is not "
                + "described at all: the count stays at one, the number stands at "
                + "whatever its single build cost, and the counter still changes on "
                + "screen. Raise the view count to 400 and the difference is the whole "
                + "point: a complex view is exactly where handing the value on rather "
                + "than reading it is worth the thought.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both are honest prices. Reading is what a view that DECIDES on a value "
                + "needs - which views there are, what they say next to each other; a "
                + "channel is for a value that merely moves.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

/// The complex block wired LAYER ONE: the number is read inside the closure,
/// so a press describes every leaf again.
private struct Described: ContentView {
    /// Borrowed, and READ inside this view's own closure - which is what
    /// makes that closure the reader and this whole block the price.
    @Binding var counter: Int

    let leaves: Int

    var content: any View {
        FlexLayout {
            let began = ContinuousClock.now

            ForEach(Array(0 ..< leaves), id: \.self) { index in
                BoxView()
                    .widthRequest(7)
                    .heightRequest(14)
                    .cornerRadius(2)
                    .color(Palette.outline)
                    .margin(1)
                    .id(index)
            }

            Label("Counter \(counter)")
                .fontSize(13)
                .fontAttributes(.bold)
                .margin(6, 0)

            Label(took(began, leaves))
                .fontSize(12)
                .textColor(Palette.accent)
                .heightRequest(15)

            DebugInfoLabel()
                .heightRequest(15)
        }
        .wrap(.wrap)
    }
}

/// The same block wired LAYER TWO: the number rides a channel, so this closure
/// is built once and its clock stands still.
private struct Channelled: ContentView {
    @Binding var counter: Int

    let leaves: Int

    var content: any View {
        FlexLayout {
            let began = ContinuousClock.now
            
            ForEach(Array(0 ..< leaves), id: \.self) { index in
                BoxView()
                    .widthRequest(7)
                    .heightRequest(14)
                    .cornerRadius(2)
                    .color(Palette.outline)
                    .margin(1)
                    .id(index)
            }

            Label($counter.convert { "Counter \($0)" })
                .fontSize(13)
                .fontAttributes(.bold)
                .margin(6, 0)

            Label(took(began, leaves))
                .fontSize(12)
                .textColor(Palette.accent)
                .heightRequest(15)

            DebugInfoLabel()
                .heightRequest(15)
        }
        .wrap(.wrap)
    }
}

/// How long describing this closure has taken so far, in microseconds.
///
/// Read at the top of a closure and printed at the bottom of the same one, so
/// what it measures is that closure's own work - the leaves above it included,
/// since a `ForEach` builds its views where it is written.
///
/// - Parameters:
///   - began: the clock at the top of the closure.
///   - views: how many views stand above the reading.
/// - Returns: the sentence to print.
private func took(_ began: ContinuousClock.Instant, _ views: Int) -> String {
    let spent = ContinuousClock.now - began
    let parts = spent.components
    let nanoseconds = parts.seconds * 1_000_000_000 + parts.attoseconds / 1_000_000_000

    return "\(views) views described in \(microseconds(nanoseconds)) µs, "
}

/// Nanoseconds as microseconds, to one decimal - the unit a describe lands in.
/// Written by hand, a formatter being Foundation's.
///
/// - Parameter nanoseconds: what the clock answered.
/// - Returns: the figure, without its unit.
private func microseconds(_ nanoseconds: Int64) -> String {
    let tenths = (nanoseconds + 50) / 100

    return "\(tenths / 10).\(tenths % 10)"
}
