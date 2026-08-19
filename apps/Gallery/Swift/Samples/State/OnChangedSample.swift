import StateUI

/// Running something when a value is not what it was last render.
struct OnChangedSample: SampleContent {
    @State private var celsius = 20.0
    @State private var log: [String] = []
    @State private var fired = 0

    static let id = "onChanged"
    static let title = "Reacting to change"
    static let summary = "A handler that runs when a value moves - with the old value and the new one."

    static let code = """
        @State private var celsius = 20.0
        @State private var log: [String] = []
        @State private var fired = 0

        VStack {
            Label("\\(Int(celsius)) °C")

            Slider($celsius)
                .minimum(-10)
                .maximum(40)

            // Watches ROUNDED degrees, so dragging fires once per whole
            // degree rather than once per pixel. It does not fire when the
            // page appears - a view arriving is not a value changing.
            VStack {
                ForEach(log.reversed()) { line in
                    Label(line).id(line)
                }
            }
            .onChanged(Int(celsius)) { old, new in
                fired += 1
                let arrow = new > old ? "warmer" : "colder"
                log.append("\\(old) -> \\(new) °C, \\(arrow) (#\\(fired))")
                if log.count > 6 { log.removeFirst() }
            }
        }
        """

    var content: Element {
        VStack {
            Label("\(Int(celsius)) °C")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalOptions(.center)

            Slider($celsius)
                .minimum(-10)
                .maximum(40)

            // Watches ROUNDED degrees, so dragging fires once per whole degree
            // rather than once per pixel. It does not fire when the page
            // appears - a view arriving is not a value changing.
            VStack {
                ForEach(log.reversed()) { line in
                    Label(line)
                        .fontSize(13)
                        .id(line)
                }
            }
            .spacing(4)
            .onChanged(Int(celsius)) { old, new in
                fired += 1
                let arrow = new > old ? "warmer" : "colder"
                log.append("\(old) -> \(new) °C, \(arrow) (#\(fired))")
                if log.count > 6 { log.removeFirst() }
            }

            Label("`.onChanged` compares against what THIS view carried last "
                + "render, on the Swift side alone - nothing about it crosses to "
                + "MAUI. The two-argument form is handed the old value and the "
                + "new one; the short form takes no arguments at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
