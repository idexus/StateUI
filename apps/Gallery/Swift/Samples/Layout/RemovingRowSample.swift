import StateUI

/// A row taken away, and the stack closing over it.
struct RemovingRowSample: SampleContent {
    static let id = "removingRow"
    static let title = "Removing a row"
    static let summary = "A row fades where it stands and the stack closes over it - a plain VStack, and the switch chooses whether the row itself takes its time."

    /// The rows, and which of them have gone.
    static let rows = ["Milk", "Bread", "Coffee", "Apples", "Butter", "Rice"]

    @State private var gone: Set<String> = []
    @State private var atOnce: Set<String> = []
    @State private var slow = true

    static let code = """
        @State private var gone: Set<String> = []
        @State private var atOnce: Set<String> = []
        @State private var slow = true

        // A PLAIN VStack. Nothing here ASKS for animation: the row is HIDDEN,
        // which fades it where it stands, and the rows under it are then given
        // new places - which is somewhere they travel to. The one line about
        // motion is the switch turning it OFF.
        VStack {
            ForEach(rows, id: \\.self) { row in
                Grid {
                    Label(row).gridColumn(0)

                    Button("Delete")
                        .gridColumn(1)
                        .onClicked { remove(row) }
                }
                .columnDefinitions(.star, .auto)
                .isVisible(!gone.contains(row) && !atOnce.contains(row))
                // What the switch below chooses: a row told to travel at NO
                // motion goes at once, and the stack still closes over it.
                .motion(atOnce.contains(row) ? .none : .inherited)
            }
        }

        SwitchRow("The row fades first", $slow)

        /// Takes a row away - fading it where it stands, or at once.
        private func remove(_ row: String) {
            if slow {
                gone.insert(row)
            } else {
                atOnce.insert(row)
            }
        }
        """

    var example: Element {
        VStack {
            VStack {
                ForEach(Self.rows, id: \.self) { row in
                    Grid {
                        Label(row)
                            .fontSize(15)
                            .verticalOptions(.center)
                            .gridColumn(0)

                        Button("Delete")
                            .fontSize(12)
                            .padding(10, 4)
                            .gridColumn(1)
                            .onClicked { remove(row) }
                    }
                    .columnDefinitions(.star, .auto)
                    .padding(14, 6)
                    .backgroundColor(Palette.raised)
                    .heightRequest(46)
                    .isVisible(!gone.contains(row) && !atOnce.contains(row))
                    // The other half of the sample: a row told to travel at no
                    // motion goes at once, and the stack still closes over it.
                    .motion(atOnce.contains(row) ? .none : .inherited)
                }
            }
            .spacing(6)

            SwitchRow("The row fades first", $slow)

            Button("Bring them back").onClicked {
                gone.removeAll()
                atOnce.removeAll()
            }
        }
        .spacing(12)
    }

    /// Takes a row away - fading it where it stands, or at once.
    private func remove(_ row: String) {
        if slow {
            gone.insert(row)
        } else {
            atOnce.insert(row)
        }
    }

    var notes: Element? {
        VStack {
            Label("Delete a row. It FADES where it stands and the rows under it "
                + "then close over the gap - a plain `VStack`, and not a line in "
                + "the example ASKING for animation: the row is hidden, and the "
                + "ones below it are given new places.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("`The row fades first` chooses how the row itself leaves. "
                + "Turned off, the row is told `.motion(.none)` and goes at "
                + "once - the stack still closes over it, because where a "
                + "child sits is always somewhere it travels to.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("`Bring them back` is the same thing the other way round: the "
                + "rows appear at nothing and come up while everything below "
                + "them moves down to make room.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
