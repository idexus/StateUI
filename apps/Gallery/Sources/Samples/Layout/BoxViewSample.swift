import StateUI

/// Rectangles of colour - square, rounded, round and faded - and a divider.
struct BoxViewSample: SampleContent, ExampleContent {
    static let id = "boxView"
    static let title = "BoxView"
    static let summary = "A rectangle of colour - the simplest thing a host draws."

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

    var content: any View {
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
        Label("A BoxView draws the colour its initializer takes, which is its `.color`. "
            + "`.backgroundColor` is a second surface behind it that the corner radius "
            + "does not round. A one-pixel BoxView is also the usual divider.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
