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

            // What one child asks for, written on the child.
            FlexLayout {
                Tag(text: "grow 1, basis 50%")
                    .flexLayoutGrow(1)
                    .flexLayoutBasis(.percent(0.5))

                Tag(text: "auto")
                    .flexLayoutAlignSelf(.end)
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

            Label("The layout's own properties are modifiers on it; what one child wants "
                + "for itself is written on the child - .flexLayoutGrow, .flexLayoutBasis - "
                + "the rule .gridRow already follows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A basis travels as MAUI writes it: auto, 50%, 120.")
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
