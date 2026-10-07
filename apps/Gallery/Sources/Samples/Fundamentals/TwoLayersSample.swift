import StateUI

/// The two layers of reactivity side by side, and then what each costs.
///
/// Layer one is a GET: `Text("Counter \(counter)")` reads the value, which
/// makes the closure it is written in a reader, and a write builds that
/// closure again. Layer two is a CHANNEL: `Text($counter.convert { … })`
/// hands the state on, the host writes the words on its own frames, and
/// nothing is built at all.
struct TwoLayersSample: SampleContent {
    static let id = "two-layers"
    static let title = "Two layers of reactivity"
    static let summary = "A value read rebuilds its reader; the same value handed on as a channel rebuilds nothing."

    var examples: [Example] {
        [Example(LayerRows()), Example(LayerCost())]
    }
}

/// The two layers side by side, each in a closure of its own so its build
/// count is its own.
private struct LayerRows: ExampleContent {
    // listing: LayerRows
    /// The one value both rows show - held here, where it is shown.
    @State private var counter = 0

    var body: some View {
        // Each layer stands in a row of its own below, so each takes its
        // own reading.
        VStack {
            // Nothing here reads the count - a handler reads when it fires -
            // so this closure stands at one build however often you press.
            DebugInfoLabel()

            Button("+1")
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            boxed("Layer one · a get") {
                Text("Counter \(counter)")
                    .fontSize(20)
                    .fontAttributes(.bold)
                DebugInfoLabel()   // climbs, "for counter"
            }

            boxed("Layer two · a channel") {
                Text($counter.convert { "Counter \($0)" })
                    .fontSize(20)
                    .fontAttributes(.bold)
                DebugInfoLabel()   // stays: "1 build, first time"
            }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Both rows show the same number. The first reads it, so every press "
                + "builds that row again, compares it and sends what changed. The second "
                + "hands the state on and the host writes the words itself, so the row "
                + "is built once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`$counter.convert { \"Counter \\($0)\" }` is what the channel says: a "
                + "second value the host carries, worked out from the first. Press +1 "
                + "and watch the two build counts part.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }

    // listing: LayerRows
    /// One captioned row, its content in a closure of its own - which is what
    /// makes the reading inside it that row's alone.
    private func boxed<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        ZStack {
            VStack {
                Text(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }
    // listing: end
}

/// The same two layers over a subtree worth describing, each side timing its
/// own describe - which is the comparison in microseconds.
private struct LayerCost: ExampleContent {
    // listing: LayerCost
    /// The value the two blocks show, one reading it and one handed it.
    @State private var counter = 0

    /// How many views stand in each block - the thing a rebuild describes.
    @State private var leaves = 100

    var body: some View {
        // The same two layers inside a subtree worth describing: `leaves`
        // little views, plus the counter. Each side times its OWN describe -
        // the clock is read at the top of the closure and again at the
        // bottom - so the number is what describing it cost.
        VStack {
            // In layer one the get is in the block's own closure, so a press
            // describes every leaf in it again, and its reading says how long
            // that took.
            HStack {
                Button("+1")
                    .onClicked { counter += 1 }

                // A choice of more than two, so a button that cycles them.
                Button("Views: \(leaves)")
                    .onClicked { leaves = leaves == 25 ? 100 : leaves == 100 ? 400 : 25 }
            }
            .spacing(10)
            .horizontalAlignment(.center)

            Text("Layer one · a get")
                .fontSize(11)
                .textColor(Palette.subtle)

            Described(counter: $counter, leaves: leaves)

            Text("Layer two · a channel")
                .fontSize(11)
                .textColor(Palette.subtle)

            Channelled(counter: $counter, leaves: leaves)
        }
        .spacing(8)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Two blocks of the same views, one number shown two ways. Each block "
                + "reads the clock at the top of its closure and again at the bottom, so "
                + "what it prints is what describing it cost.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Press +1: the first block is described again - every view in it - so "
                + "its build count climbs and its microseconds are taken afresh. The "
                + "second is not described at all, and its count stays at one. Raise the "
                + "views to 400 and the difference grows with them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Reading is what a view that decides by a value needs; a channel is for "
                + "a value that only moves.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

// listing: LayerCost
/// The block wired to layer one: the number is read inside the closure, so a
/// press describes every leaf again.
private struct Described: View {
    /// Borrowed, and READ inside this view's own closure - which is what
    /// makes that closure the reader and this whole block the price.
    @Binding var counter: Int

    let leaves: Int

    var body: some View {
        VStack {
            let began = ContinuousClock.now

            // The leaves in rows of 25: a stack wraps nothing, so the rows do.
            ForEach(Array(stride(from: 0, to: leaves, by: 25)), id: \.self) { row in
                HStack {
                    ForEach(Array(row ..< min(row + 25, leaves)), id: \.self) { index in
                        ColorBox()
                            .width(7)
                            .height(14)
                            .cornerRadius(2)
                            .color(Palette.outline)
                            .margin(1)
                            .id(index)
                    }
                }
                .spacing(2)
            }

            HStack {
                Text("Counter \(counter)")
                    .fontSize(13)
                    .fontAttributes(.bold)
                    .margin(horizontal: 6, vertical: 0)

                Text(took(began, leaves))
                    .fontSize(12)
                    .textColor(Palette.accent)
                    .height(15)

                DebugInfoLabel()   // climbs on every press
                    .height(15)
            }
            .spacing(2)
        }
        .spacing(2)
    }
}
// listing: end

// listing: LayerCost
/// The same block wired to layer two: the number rides a channel, so +1
/// builds nothing here and its clock stands still.
private struct Channelled: View {
    @Binding var counter: Int

    let leaves: Int

    var body: some View {
        VStack {
            let began = ContinuousClock.now

            // The leaves in rows of 25: a stack wraps nothing, so the rows do.
            ForEach(Array(stride(from: 0, to: leaves, by: 25)), id: \.self) { row in
                HStack {
                    ForEach(Array(row ..< min(row + 25, leaves)), id: \.self) { index in
                        ColorBox()
                            .width(7)
                            .height(14)
                            .cornerRadius(2)
                            .color(Palette.outline)
                            .margin(1)
                            .id(index)
                    }
                }
                .spacing(2)
            }

            HStack {
                Text($counter.convert { "Counter \($0)" })
                    .fontSize(13)
                    .fontAttributes(.bold)
                    .margin(horizontal: 6, vertical: 0)

                Text(took(began, leaves))
                    .fontSize(12)
                    .textColor(Palette.accent)
                    .height(15)

                DebugInfoLabel()   // stays at one on +1
                    .height(15)
            }
            .spacing(2)
        }
        .spacing(2)
    }
}
// listing: end

// listing: LayerCost
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

    return "\(views) views described in \(microseconds(nanoseconds)) µs"
}
// listing: end

// listing: LayerCost
/// Nanoseconds as microseconds, to one decimal - the unit a describe lands in.
/// Written by hand, a formatter being Foundation's.
///
/// - Parameter nanoseconds: what the clock answered.
/// - Returns: the figure, without its unit.
private func microseconds(_ nanoseconds: Int64) -> String {
    let tenths = (nanoseconds + 50) / 100

    return "\(tenths / 10).\(tenths % 10)"
}
// listing: end
