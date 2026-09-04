import StateUI

/// MAUI: BoxView.
struct BoxViewSample: SampleContent {
    static let id = "boxView"
    static let title = "BoxView"
    static let summary = "A rectangle of colour - the simplest thing MAUI draws."

    static let code = """
        VStack {
            HStack {
                BoxView(Palette.accent)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Palette.accent)
                    .cornerRadius(22)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Color.fromArgb("#E53935"))
                    .cornerRadius(10)
                    .opacity(0.4)
                    .widthRequest(44)
                    .heightRequest(44)
            }

            // A one-pixel BoxView is also the usual divider.
            BoxView(Palette.outline)
                .heightRequest(1)
        }
        """

    var example: Element {
        VStack {
            HStack {
                BoxView(Palette.accent)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Palette.accent)
                    .cornerRadius(22)
                    .widthRequest(44)
                    .heightRequest(44)

                BoxView(Color.fromArgb("#E53935"))
                    .cornerRadius(10)
                    .opacity(0.4)
                    .widthRequest(44)
                    .heightRequest(44)
            }
            .spacing(12)
            .horizontalOptions(.center)

            BoxView(Palette.outline)
                .heightRequest(1)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Color, not BackgroundColor: a BoxView has both, and Color is the one "
            + "it draws with. A one-pixel BoxView is also the usual divider.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
