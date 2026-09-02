import StateUI

/// A layout whose children travel to their new places when the layout changes.
struct LivingLayoutSample: SampleContent {
    static let id = "livingLayout"
    static let title = "A layout that moves"
    static let summary = "Insert, remove or reorder, and everything else slides to its new place - in a stack, and in a grid whose columns change width."

    @State private var rows = ["Alpha", "Bravo", "Charlie"]
    @State private var next = 4
    @State private var wide = false

    static let names = ["Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India"]

    static let code = """
        @State private var rows = ["Alpha", "Bravo", "Charlie"]
        @State private var next = 4

        let names = ["Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India"]

        // NOTHING HERE SAYS "ANIMATE". Where a child sits is worked out by the
        // layout; what carries it from the old place to the new one is the
        // host's engine, so an insert slides everything under it down.
        VStack {
            ForEach(rows, id: \\.self) { name in
                Border { Label(name) }
            }
        }

        HStack {
            Button("Add").onClicked {
                rows.insert(names[next % names.count], at: 0)
                next += 1
            }
            Button("Remove").onClicked { rows.removeLast() }
            Button("Shuffle").onClicked { rows.shuffle() }
        }

        // A grid whose column widths change: every child crosses to its new
        // column, because a placement is a placement whoever worked it out.
        Grid {
            Label("one").gridColumn(0)
            Label("two").gridColumn(1)
        }
        .columnDefinitions(wide ? .star(3) : .star(1), wide ? .star(1) : .star(3))
        """

    var content: Element {
        VStack {
            Label("A STACK")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            VStack {
                ForEach(rows, id: \.self) { name in
                    Border {
                        Label(name)
                            .fontSize(15)
                            .verticalOptions(.center)
                    }
                    .padding(Thickness(12, 8, 12, 8))
                    .backgroundColor(Palette.raised)
                    .strokeThickness(0)
                    .heightRequest(40)
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

            Label("A GRID, ITS COLUMNS CHANGING WIDTH")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            Grid {
                cell("one", Palette.brand, at: 0)
                cell("two", Palette.accent, at: 1)
                cell("three", Palette.brand, at: 2, faded: true)
            }
            .columnDefinitions(
                wide ? .star(3) : .star(1),
                .star(1),
                wide ? .star(1) : .star(3))
            .columnSpacing(8)
            .heightRequest(52)

            Button("Widen the other end").onClicked { wide.toggle() }
        }
        .spacing(10)
    }

    private func cell(
        _ text: String, _ colour: Color, at column: Int, faded: Bool = false
    ) -> Element {
        Border {
            Label(text)
                .fontSize(13)
                .textColor(Palette.onBrand)
                .horizontalOptions(.center)
                .verticalOptions(.center)
        }
        .backgroundColor(colour)
        .opacity(faded ? 0.55 : 1)
        .strokeThickness(0)
        .gridColumn(column)
    }

    var notes: Element? {
        VStack {
            Label("Add a row and the ones under it SLIDE down; remove one and "
                + "they close up; shuffle and they cross past each other. The "
                + "example says nothing about animation: it writes "
                + "`rows.insert(…)`, and the layout works out where everything "
                + "belongs exactly as it always did.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The grid is the same thing one level up. Its columns change "
                + "width, so every child gets a new place - and a place a child "
                + "is given is somewhere it travels to. A view that ARRIVES "
                + "fades in; one that leaves goes at once and the gap closes "
                + "behind it.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A layout's own SIZE changing is different, and deliberately: "
                + "drag the window and the children track it exactly, because a "
                + "resize is something a reader is doing rather than something "
                + "the interface decided.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
