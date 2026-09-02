import StateUI

/// A value that changes TRAVELS - the default, and the three laws it can travel
/// under.
struct MotionSample: SampleContent {
    static let id = "motion"
    static let title = "Motion"
    static let summary = "A value that changes travels to it. Assign the state and the control goes there - at a length, on a spring, or not at all."

    static let laws = ["Eased 200ms", "Spring", "Long and slow", "None"]

    static func law(_ index: Int) -> Motion {
        switch index {
        case 1: .spring(response: 320)
        case 2: .eased(900, .sinInOut)
        case 3: .none
        default: .standard
        }
    }

    @State private var law = 0
    @State private var wide = false
    @State private var warm = false

    static let code = """
        @State private var wide = false
        @State private var warm = false

        // NOTHING HERE SAYS "ANIMATE". A value that changes is a setpoint: the
        // tree says where the panel is going and the host carries it there.
        VStack {
            BoxView()
                .color(warm ? Palette.accent : Palette.brand)
                .widthRequest(wide ? 300 : 120)
                .heightRequest(wide ? 120 : 60)
                .cornerRadius(wide ? 32 : 8)

            // The same panel, told to stay still. `.motion` is per view.
            BoxView()
                .color(warm ? Palette.accent : Palette.brand)
                .widthRequest(wide ? 300 : 120)
                .heightRequest(wide ? 120 : 60)
                .cornerRadius(wide ? 32 : 8)
                .motion(.none)

            // And the same panel again, with a rule: everything travels
            // EXCEPT how big it is, which arrives. The last rule that names a
            // value is the one that answers for it.
            BoxView()
                .color(warm ? Palette.accent : Palette.brand)
                .widthRequest(wide ? 300 : 120)
                .heightRequest(wide ? 120 : 60)
                .cornerRadius(wide ? 32 : 8)
                .motion(.none, .size)

            HStack {
                Button("Size").onClicked { wide.toggle() }
                Button("Colour").onClicked { warm.toggle() }
            }
        }
        """

    var content: Element {
        VStack {
            Label("A CHANGE THAT TRAVELS")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            panel(travels: true)

            Label("THE SAME, TOLD TO STAY STILL")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            panel(travels: false)

            Label("AND THE SAME, HOLDING ONLY ITS SIZE STILL")
                .fontSize(11)
                .characterSpacing(1)
                .textColor(Palette.subtle)

            sized()

            HStack {
                Button("Size").onClicked { wide.toggle() }
                Button("Colour").onClicked { warm.toggle() }
                Button(Self.laws[law]).onClicked { law = (law + 1) % Self.laws.count }
            }
            .spacing(8)
        }
        .spacing(10)
    }

    /// One panel, either travelling at the chosen law or arriving at once.
    private func panel(travels: Bool) -> Element {
        BoxView()
            .color(warm ? Palette.accent : Palette.brand)
            .widthRequest(wide ? 300 : 120)
            .heightRequest(wide ? 110 : 56)
            .cornerRadius(wide ? 28 : 8)
            .horizontalOptions(.start)
            .motion(travels ? Self.law(law) : .none)
    }

    /// The same panel with a RULE: everything travels except how big it is.
    private func sized() -> Element {
        BoxView()
            .color(warm ? Palette.accent : Palette.brand)
            .widthRequest(wide ? 300 : 120)
            .heightRequest(wide ? 110 : 56)
            .cornerRadius(wide ? 28 : 8)
            .horizontalOptions(.start)
            .motion(Self.law(law))
            .motion(.none, .size)
    }

    var notes: Element? {
        VStack {
            Label("Press a button and watch the panels. The top one TRAVELS "
                + "to its new width, height, corner and colour; the second is "
                + "simply there. Neither of them says a word about animation - the "
                + "example writes `wide.toggle()` and nothing else.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The third button cycles the LAW the top panel travels under. "
                + "A length is a movement that takes as long as it is told; a "
                + "spring answers as fast as its response says and settles when "
                + "it is done; none is a value that simply arrives. `.motion` is "
                + "written on a view, `Application.motion` sets a whole app, and "
                + "`$state.snap(to:)` holds one write still.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The THIRD panel says `.motion(.none, .size)` under its law: "
                + "a motion can name WHICH values it is about, and the last "
                + "rule that names one answers for it. Press Size and watch it "
                + "take its new width, height and corner at once, while Colour "
                + "still crosses it exactly like the first panel. The names "
                + "are groups - opacity, colour, size, width, height, place, "
                + "transform, spacing, text - and each one says which MAUI "
                + "properties it covers.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
