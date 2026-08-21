import StateUI

/// MAUI: FlexLayout.
struct FlexLayoutSample: SampleContent {
    @State private var wrap = true
    @State private var justify = FlexJustify.start

    static let id = "flexLayout"
    static let title = "FlexLayout"
    static let summary = "CSS flexbox: a line that wraps, shares out what is left, and lets one child take more of it."

    static let code = """
        @State private var wrap = true
        @State private var justify = FlexJustify.start

        private static let tags = [
            "Label", "Button", "Entry", "Editor", "Switch",
            "Slider", "Picker", "Border", "Grid",
        ]

        VStack {
            FlexLayout {
                ForEach(Self.tags) { tag in
                    Tag(text: tag)
                        .id(tag)
                }
            }
            .wrap(wrap ? .wrap : .noWrap)
            .justifyContent(justify)
            .alignItems(.center)

            HStack {
                Button(wrap ? "Wrap" : "No wrap")
                    .onClicked { wrap.toggle() }

                Button("justifyContent: .\\(justify)")
                    .onClicked { justify = Self.next(after: justify) }
            }
        }

        /// The four worth showing, in the order a reader would try them.
        private static func next(after value: FlexJustify) -> FlexJustify {
            switch value {
            case .start: return .center
            case .center: return .spaceBetween
            case .spaceBetween: return .spaceEvenly
            default: return .start
            }
        }

        // -- WHICH WAY THE LINE RUNS --

        // The same three chips in two boxes of the same size, so the only
        // thing between them is the axis the line runs along.
        Grid {
            FlexLayout {
                Tag(text: "1")
                Tag(text: "2")
                Tag(text: "3")
            }
            .direction(.row)
            .alignItems(.center)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center)

            FlexLayout {
                Tag(text: "1")
                Tag(text: "2")
                Tag(text: "3")
            }
            .direction(.column)
            .alignItems(.center)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center)
            .gridColumn(1)
        }
        .columnDefinitions(.star, .star)
        .columnSpacing(12)

        // -- WHERE THE WRAPPED LINES GO --

        private static let letters = ["A", "B", "C", "D", "E", "F"]

        // A box narrow enough that the six chips make two lines, and taller
        // than the two lines together - that leftover height is what
        // alignContent shares out. It says nothing at all while everything is
        // on one line.
        Grid {
            FlexLayout {
                ForEach(Self.letters) { letter in
                    Tag(text: letter)
                        .id(letter)
                }
            }
            .wrap(.wrap)
            .alignContent(.start)
            .alignItems(.center)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center)

            FlexLayout {
                ForEach(Self.letters) { letter in
                    Tag(text: letter)
                        .id(letter)
                }
            }
            .wrap(.wrap)
            .alignContent(.spaceBetween)
            .alignItems(.center)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center)
            .gridColumn(1)
        }
        .columnDefinitions(.star, .star)
        .columnSpacing(12)

        // -- WHAT A CHILD ASKS FOR --

        // Written on the child, the rule .gridRow already follows: the first
        // takes what is spare, the second keeps what it measures at.
        FlexLayout {
            Tag(text: "grow 1, basis 50%")
                .flexLayoutGrow(1)
                .flexLayoutBasis(.percent(0.5))

            Tag(text: "auto")
                .flexLayoutAlignSelf(.end)
        }

        // Order is 0 unless a child says otherwise, and the line runs from the
        // lowest to the highest - so the chip written first is drawn last,
        // without moving in the source.
        FlexLayout {
            Tag(text: "1st written")
                .flexLayoutOrder(2)

            Tag(text: "2nd written")

            Tag(text: "3rd written")
        }

        // Both ask for 170 in a row no wider than 280, which is not enough for
        // the pair: shrink is the share of that shortfall a child gives up,
        // and 0 gives up none of it.
        FlexLayout {
            Tag(text: "shrink 0")
                .flexLayoutBasis(.length(170))
                .flexLayoutShrink(0)

            Tag(text: "shrink 1")
                .flexLayoutBasis(.length(170))
                .flexLayoutShrink(1)
        }
        .wrap(.noWrap)
        .maximumWidthRequest(280)

        private struct Tag: ContentView {
            let text: String

            var content: Element {
                Label(text)
                    .textColor(Palette.onAccent)
                    .backgroundColor(Palette.accent)
                    .padding(10, 6)
                    .margin(4)
            }
        }
        """

    private static let tags = [
        "Label", "Button", "Entry", "Editor", "Switch",
        "Slider", "Picker", "Border", "Grid",
    ]

    /// Six short chips, which is what makes more than one LINE in a narrow box
    /// - and alignContent has nothing to say until there is a second line.
    private static let letters = ["A", "B", "C", "D", "E", "F"]

    var content: Element {
        VStack {
            FlexLayout {
                ForEach(Self.tags) { tag in
                    Tag(text: tag)
                        .id(tag)
                }
            }
            .wrap(wrap ? .wrap : .noWrap)
            .justifyContent(justify)
            .alignItems(.center)

            HStack {
                Button(wrap ? "Wrap" : "No wrap")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { wrap.toggle() }

                Button(name(of: justify))
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { justify = Self.next(after: justify) }
            }
            .spacing(10)
            .horizontalOptions(.center)

            SectionTitle("WHICH WAY THE LINE RUNS")

            // The same three chips in boxes of the same size, so the only
            // thing between the two is the axis they run along.
            Grid {
                directionCase(.row, "direction: .row")

                directionCase(.column, "direction: .column")
                    .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            SectionTitle("WHERE THE WRAPPED LINES GO")

            Grid {
                alignContentCase(.start, "alignContent: .start")

                alignContentCase(.spaceBetween, "alignContent: .spaceBetween")
                    .gridColumn(1)
            }
            .columnDefinitions(.star, .star)
            .columnSpacing(12)

            SectionTitle("WHAT A CHILD ASKS FOR")

            // The three properties a flex child answers with, on one row: the
            // first takes what is spare, the second keeps what it measures at.
            FlexLayout {
                Tag(text: "grow 1, basis 50%")
                    .flexLayoutGrow(1)
                    .flexLayoutBasis(.percent(0.5))

                Tag(text: "auto")
                    .flexLayoutAlignSelf(.end)
            }

            // Order is 0 unless a child says otherwise, and the line runs from
            // the lowest to the highest - so the chip written first is drawn
            // last, without moving in the source.
            labelled(".flexLayoutOrder(2) on the one written first",
                FlexLayout {
                    Tag(text: "1st written")
                        .flexLayoutOrder(2)

                    Tag(text: "2nd written")

                    Tag(text: "3rd written")
                })

            // Both children ask for 170 in a row no wider than 280. Shrink is
            // the share of that shortfall a child gives up, and 0 gives up
            // none of it.
            labelled(".flexLayoutBasis(.length(170)) on both, .flexLayoutShrink(0) on the left",
                FlexLayout {
                    Tag(text: "shrink 0")
                        .flexLayoutBasis(.length(170))
                        .flexLayoutShrink(0)

                    Tag(text: "shrink 1")
                        .flexLayoutBasis(.length(170))
                        .flexLayoutShrink(1)
                }
                .wrap(.noWrap)
                .maximumWidthRequest(280)
                .horizontalOptions(.center))

            Label("The layout's own properties are modifiers on it; what one child wants "
                + "for itself is written on the child - .flexLayoutGrow, .flexLayoutBasis - "
                + "the rule .gridRow already follows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A basis travels as MAUI writes it: auto, 50%, 120.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`alignItems` places each child ACROSS the direction; `alignContent` "
                + "places the LINES themselves, so it needs wrapping and a cross size with "
                + "room to spare. One line, or a layout that measures itself, and it does "
                + "nothing at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// The four worth showing, in the order a reader would try them.
    private static func next(after value: FlexJustify) -> FlexJustify {
        switch value {
        case .start: return .center
        case .center: return .spaceBetween
        case .spaceBetween: return .spaceEvenly
        default: return .start
        }
    }

    private func name(of value: FlexJustify) -> String {
        "justifyContent: .\(value)"
    }

    /// One direction, in a box big enough for the three chips either way round.
    private func directionCase(_ value: FlexDirection, _ caption: String) -> VStack {
        labelled(caption,
            FlexLayout {
                Tag(text: "1")
                Tag(text: "2")
                Tag(text: "3")
            }
            .direction(value)
            .alignItems(.center)
            .backgroundColor(Palette.raised)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center))
    }

    /// One alignContent, over a box NARROW enough that the six chips make two
    /// lines and taller than the two lines together - which is where the spare
    /// room it shares out comes from.
    private func alignContentCase(_ value: FlexAlignContent, _ caption: String) -> VStack {
        labelled(caption,
            FlexLayout {
                ForEach(Self.letters) { letter in
                    Tag(text: letter)
                        .id(letter)
                }
            }
            .wrap(.wrap)
            .alignContent(value)
            .alignItems(.center)
            .backgroundColor(Palette.raised)
            .maximumWidthRequest(140)
            .heightRequest(130)
            .horizontalOptions(.center))
    }

    /// One example with the setting that made it named underneath, so a pair
    /// reads as one difference rather than two pictures. A stack rather than an
    /// Element, so the caller can still say which grid column it goes in.
    private func labelled(_ caption: String, _ view: Element) -> VStack {
        VStack {
            view

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(6)
    }
}

/// One chip, so the layout has something with a size of its own to arrange.
private struct Tag: ContentView {
    let text: String

    var content: Element {
        Label(text)
            .fontSize(12)
            .textColor(Palette.onAccent)
            .backgroundColor(Palette.accent)
            .padding(10, 6)
            .margin(4)
    }
}
