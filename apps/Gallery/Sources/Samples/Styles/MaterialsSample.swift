import StateUI

/// What a surface is made of: a colour, a gradient, a blur of what lies behind
/// it, or the platform's glass - laid over stripes of colour, so what each one
/// lets through shows.
struct MaterialsSample: SampleContent, ExampleContent {
    // listing: MaterialsSample
    /// Which of the blurs the blurred panel wears.
    @State private var thickness = 2

    /// Whether the blur wears the gallery's colour as a tint.
    @State private var tinted = false

    /// Whether the glass is the clearer kind.
    @State private var clear = false

    /// Whether the glass answers the touch and the pointer.
    @State private var interactive = false

    /// The colour the last panel walks to and back - a colour's channel.
    @State private var wash = Palette.accent
    // listing: end

    static let id = "materials"
    static let title = "Materials"
    static let summary = "What a surface is made of: a colour, a gradient, a blur of what is behind it, or glass."

    static var code: String { Listings.joined("MaterialsSample") }

    // listing: MaterialsSample
    /// The blurs on offer, thinnest first.
    private static let blurs: [(name: String, blur: Blur)] = [
        ("Ultra thin", .ultraThin), ("Thin", .thin), ("Regular", .regular), ("Thick", .thick),
        ("Ultra thick", .ultraThick),
    ]

    var body: some View {
        let chosen = Self.blurs[thickness].blur
        let blur = tinted ? chosen.tint(Palette.accent.opacity(0.25)) : chosen
        let glass = (clear ? Glass.clear : .regular).isInteractive(interactive)

        return VStack {
            ZStack {
                // Stripes of colour behind the panels: what each lets through shows on them.
                Grid {
                    Rectangle().fill(.tomato).gridColumn(0)
                    Rectangle().fill(.gold).gridColumn(1)
                    Rectangle().fill(.steelBlue).gridColumn(2)
                    Rectangle().fill(.white).gridColumn(3)
                    Rectangle().fill(Palette.accent).gridColumn(4)
                }
                .columns(.fill, .fill, .fill, .fill, .fill)

                Grid {
                    panel("Colour", .color(Palette.accent)).gridRow(0).gridColumn(0)
                    panel("Gradient", .gradient(Palette.identity)).gridRow(0).gridColumn(1)
                    panel("Blur", .blur(blur)).gridRow(1).gridColumn(0)
                    panel("Glass", .glass(glass)).gridRow(1).gridColumn(1)
                    // A blur in the dark theme, and nearly white in the light one.
                    panel("Light and dark", Material(light: .color(Color.white.opacity(0.85)), dark: .blur(.regular)))
                        .gridRow(2).gridColumn(0)
                    // A colour's channel: the host walks the colour, and no view is built again.
                    words("A colour's channel")
                        .background($wash)
                        .shape(.roundedRectangle(14))
                        .height(76)
                        .gridRow(2).gridColumn(1)
                }
                .columns(.fill, .fill)
                .rowSpacing(12)
                .columnSpacing(12)
                .padding(16)
            }
            .shape(.roundedRectangle(14))
            .clipsContent(true)

            Picker(Self.blurs.map(\.name))
                .accessibilityIdentifier("materials.thickness")
                .accessibilityLabel("Blur")
                .selectedIndex($thickness)
            SwitchRow("Tinted blur", $tinted)
            SwitchRow("Clear glass", $clear)
            SwitchRow("Glass answers the touch", $interactive)
            Button("Change the colour")
                .horizontalAlignment(.center)
                .onClicked { wash = wash == Palette.accent ? Palette.brand : Palette.accent }
        }
        .spacing(10)
    }

    /// A panel of `material`, named.
    private func panel(_ name: String, _ material: Material) -> ZStack {
        words(name)
            .background(material)
            .shape(.roundedRectangle(14))
            .height(76)
    }

    /// A panel's name, in its middle.
    private func words(_ name: String) -> ZStack {
        ZStack {
            Text(name)
                .fontSize(13)
                .fontAttributes(.bold)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
        }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A background is a material: a colour, a gradient, a blur of what lies behind the view, "
                + "or the platform's glass, each cut to the view's shape. A tint lies over a blur or "
                + "glass alike; this glass wears none, so the platform's own shows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`Material(light:dark:)` gives each theme its own; one with no pair is the same in "
                + "both, the blur and glass following the theme as the platform draws them. A platform "
                + "with no glass draws the blur as clear as the glass, one that blurs nothing a colour "
                + "of the theme in its place.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.background($wash)` hands the colour to the host as a channel: it walks the colour "
                + "to each new one, and nothing here is built again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
