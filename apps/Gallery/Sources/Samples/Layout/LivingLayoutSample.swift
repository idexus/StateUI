import StateUI

/// A layout whose children travel to their new places when the layout changes.
struct LivingLayoutSample: SampleContent, ExampleContent {
    static let id = "livingLayout"
    static let title = "A layout that moves"
    static let summary = "Insert, remove or reorder, and everything else slides to its new place."

    @State private var rows = ["Alpha", "Bravo", "Charlie"]
    @State private var next = 4
    @State private var wide = false

    static let names = ["Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India"]

    static let code = """
        @State private var rows = ["Alpha", "Bravo", "Charlie"]
        @State private var next = 4
        @State private var wide = false

        let names = ["Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India"]

        // NOTHING HERE SAYS "ANIMATE". Where a child sits is worked out by the
        // layout; what carries it from the old place to the new one is the
        // host's engine, so an insert slides everything under it down.
        VStack {
            // `wide` is read in THESE braces - `.columns` below asks
            // it - so widening the grid builds this closure. What the rows do
            // is counted by the reading inside their own stack.
            DebugInfoLabel()

            VStack {
                // INSIDE these braces, because that is where `rows` is read:
                // Add, Remove and Shuffle build this closure, and the views
                // left standing keep their controls.
                DebugInfoLabel()

                ForEach(rows, id: \\.self) { name in
                    Border { Label(name) }
                }
            }

            HStack {
                Button("Add").onClicked {
                    rows.insert(names[next % names.count], at: 0)
                    next += 1
                }
                Button("Remove").onClicked {
                    if !rows.isEmpty { rows.removeLast() }
                }
                Button("Shuffle").onClicked { rows.shuffle() }
            }

            // A grid whose column widths change: every child crosses to its
            // new column, because a placement is a placement whoever worked it
            // out.
            Grid {
                Label("one").gridColumn(0)
                Label("two").gridColumn(1)
                Label("three").gridColumn(2)
            }
            .columns(
                wide ? .proportional(3) : .proportional(1),
                .proportional(1),
                wide ? .proportional(1) : .proportional(3))

            Button("Widen the other end").onClicked { wide.toggle() }
        }
        """

    var content: any View {
        VStack {
            // `wide` is read in THESE braces - `.columns` below asks
            // it - so widening the grid builds this closure. What the rows do
            // is counted by the reading inside their own stack.
            DebugInfoLabel()

            Label("A stack")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            VStack {
                // INSIDE these braces, because that is where `rows` is read:
                // Add, Remove and Shuffle build this closure, and the views
                // left standing keep their controls.
                DebugInfoLabel()

                ForEach(rows, id: \.self) { name in
                    Border {
                        Label(name)
                            .fontSize(15)
                            .verticalAlignment(.center)
                    }
                    .padding(Insets(12, 8, 12, 8))
                    .background(Palette.raised)
                    .strokeWidth(0)
                    .height(40)
                }
            }
            .spacing(6)

            HStack {
                Button("Add").onClicked {
                    rows.insert(Self.names[next % Self.names.count], at: 0)
                    next += 1
                }

                Button("Remove").onClicked {
                    if !rows.isEmpty { rows.removeLast() }
                }

                Button("Shuffle").onClicked { rows.shuffle() }
            }
            .spacing(8)

            Label("A grid, its columns changing width")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            Grid {
                cell("one", Palette.brand, at: 0)
                cell("two", Palette.accent, at: 1)
                cell("three", Palette.brand, at: 2, faded: true)
            }
            .columns(
                wide ? .proportional(3) : .proportional(1),
                .proportional(1),
                wide ? .proportional(1) : .proportional(3))
            .columnSpacing(8)
            .height(52)

            Button("Widen the other end").onClicked { wide.toggle() }
        }
        .spacing(10)
    }

    private func cell(
        _ text: String, _ colour: Color, at column: Int, faded: Bool = false
    ) -> any View {
        Border {
            Label(text)
                .fontSize(13)
                .textColor(Palette.onBrand)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
        }
        .background(colour)
        .opacity(faded ? 0.55 : 1)
        .strokeWidth(0)
        .gridColumn(column)
    }

    var notes: Element? {
        VStack {
            Label("Add a row and the ones under it SLIDE down; remove one and "
                + "they close up; shuffle and they cross past each other. The "
                + "example says nothing about animation: it writes "
                + "`rows.insert(…)`, and the layout works out where everything "
                + "belongs the same way it would if nothing moved.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The grid is the same thing one level up. Its columns change "
                + "width, so every child gets a new place - and a place a child "
                + "is given is somewhere it travels to. A view that ARRIVES "
                + "fades in; one that leaves goes at once and the gap closes "
                + "behind it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A layout's own SIZE changing is different, and deliberately: "
                + "drag the window and the children track it exactly, because a "
                + "resize is something a user is doing rather than something "
                + "the interface decided.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
