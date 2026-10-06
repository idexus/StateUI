import StateUI

/// What a view answers when it is asked why it is being described.
struct RebuildSample: SampleContent, ExampleContent {
    static let id = "rebuilds"
    static let title = "Why a view rebuilds"
    static let summary = "`debugInfo()` names each view and counts its builds: change one value and see who answers."

    // listing: RebuildSample
    @State private var left = 0
    @State private var right = 0

    // Reads nothing - the buttons write in handlers, the panels are handed
    // bindings - so this body is built once.
    var body: some View {
        VStack {
            HStack {
                Button("Change left")
                    .onClicked { left += 1 }

                Button("Change right")
                    .onClicked { right += 1 }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            // TWO OF THEM, because the reading is only worth anything against
            // another: one panel answers and the other stands still, and the
            // counts say which.
            RebuildPanel(name: "left", value: $left)

            RebuildPanel(name: "right", value: $right)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Every view can say why it is being described. `debugInfo()` "
                + "answers the view's own name, how many times it has been "
                + "described, and which piece of state THIS description is "
                + "for - named by the property the author declared it as.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Change one of the two values. The panel that borrowed it "
                + "names it and its count climbs; the other panel stands still, "
                + "because a render rebuilds only the views whose reads moved.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The small line inside each panel reads nothing and is "
                + "built with nothing: it is carried through every rebuild "
                + "and keeps saying `1 build, first time`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Put it in a `Text` on the screen being worked on. Reading "
                + "it causes no render of its own.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

// listing: RebuildSample
/// One value, and the reading that says why this panel was described.
private struct RebuildPanel: View {
    let name: String

    @Binding var value: Int

    var body: some View {
        ZStack {
            VStack {
                Text("\(name) is \(value)")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(Palette.text)

                // WHY THIS VIEW IS BEING DESCRIBED, on the screen it is
                // about: the view's name, how many times, and the state
                // this one is for.
                Text(debugInfo())
                    .fontSize(13)
                    .textColor(Palette.accent)

                RebuildPassenger()
            }
            .spacing(4)
            .padding(horizontal: 14, vertical: 12)
        }
        .style("Card")
        .stroke(Palette.outline)
        .lineWidth(1)
        .shape(.roundedRectangle(10))
        .background(Palette.raised)
    }
}
// listing: end

// listing: RebuildSample
/// A view that reads nothing and is built with nothing, so every rebuild of the
/// panel above it carries it: its reading stays at the first build.
private struct RebuildPassenger: View {
    var body: some View {
        Text(debugInfo())
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
// listing: end
