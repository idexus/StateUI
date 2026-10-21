import StateUI

/// Running something when a value is not what it was last render.
struct OnChangedSample: SampleContent, ExampleContent {
    // listing: OnChangedSample
    @State private var celsius = 20.0
    @State private var log: [String] = []
    @State private var fired = 0
    // listing: end

    static let id = "onChanged"
    static let title = "Reacting to change"
    static let summary = "A handler that runs when a value moves - with the old value and the new one."

    var examples: [Example] {
        [Example(self), Example(ChangesAcrossBranches())]
    }

    // listing: OnChangedSample
    var body: some View {
        VStack {
            // THIS closure reads `celsius`, so every report from the slider
            // builds it again - which is what a get on a dragged value costs.
            DebugInfoLabel()

            Text("\(Int(celsius)) °C")
                .fontSize(34)
                .fontWeight(.bold)
                .horizontalAlignment(.center)

            Slider($celsius)
                .accessibilityIdentifier("onChanged.celsius")
                .accessibilityLabel("Celsius")
                .minimum(-10)
                .maximum(40)

            // Watches WHOLE degrees, so dragging fires once per whole degree
            // rather than once per pixel. It does not fire when the page
            // appears - a view arriving is not a value changing.
            VStack {
                ForEach(log.reversed()) { line in
                    Text(line)
                        .fontSize(13)
                        .id(line)
                }
            }
            .motion(.none)
            .spacing(4)
            .onChanged(Int(celsius)) { old, new in
                fired += 1
                let arrow = new > old ? "warmer" : "colder"
                log.append("\(old) -> \(new) °C, \(arrow) (#\(fired))")
                if log.count > 6 { log.removeFirst() }
            }

        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`.onChanged` compares against what this view carried last render, on "
                + "the Swift side alone - nothing about it crosses to the host. The "
                + "two-argument form is handed the old value and the new one; the short "
                + "form takes no arguments at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("It watches whole degrees here, so dragging fires once per whole "
                + "degree rather than once per pixel. It does not fire when the page "
                + "appears: a view arriving is not a value changing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// A watch written on a group, which goes on watching whichever branch of its `if/else` shows.
private struct ChangesAcrossBranches: ExampleContent {
    // listing: ChangesAcrossBranches
    @State private var signedIn = false
    @State private var changes = 0

    var body: some View {
        VStack {
            Switch($signedIn)
                .text("Signed in")
                .accessibilityIdentifier("onChanged.signedIn")

            // Written on the group holding the `if/else`: it watches whichever
            // branch shows. The group adds no view of its own.
            Group {
                if signedIn {
                    Text("Signed in")
                        .fontWeight(.bold)
                } else {
                    Button("Sign in")
                        .onClicked { signedIn = true }
                }
            }
            .horizontalAlignment(.center)
            .onChanged(signedIn) { changes += 1 }

            Text("Changed \(changes) times")
                .accessibilityIdentifier("onChanged.changes")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("The watch is written on the group holding the `if/else`, so it goes on watching whichever "
            + "branch shows; one written inside a branch starts over with it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
