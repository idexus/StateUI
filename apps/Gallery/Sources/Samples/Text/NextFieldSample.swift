import StateUI

/// A form whose fields hand the keyboard on, one to the next, as their return key says Next.
struct NextFieldSample: SampleContent, ExampleContent {
    // listing: NextFieldSample
    @State private var name = ""
    @State private var street = ""
    @State private var city = ""
    @State private var sent = false
    // listing: end

    static let id = "nextField"
    static let title = "Next field"
    static let summary = "A return key saying Next hands the keyboard to the next field the page reads."

    // listing: NextFieldSample
    var body: some View {
        VStack {
            Text("Type a name and press Return: each field hands the keyboard to the next.")
                .fontSize(14)

            TextField($name)
                .placeholder("Name")
                .submitLabel(.next)

            Grid {
                TextField($street)
                    .placeholder("Street")
                    .submitLabel(.next)

                TextField($city)
                    .placeholder("City")
                    .submitLabel(.send)
                    .onSubmitted { sent = true }
                    .gridColumn(1)
            }
            .columns(.fill, .fill)
            .columnSpacing(8)

            Text(sent ? "Sent to \(name), \(street), \(city)" : "Not sent yet")
                .fontSize(14)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("The page is read in the order it is written - across the row, then down - and a field "
            + "hidden or disabled is passed by. The last field's return says Send: it submits, and hands nothing on.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
