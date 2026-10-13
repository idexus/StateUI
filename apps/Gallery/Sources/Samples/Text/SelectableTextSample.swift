import StateUI

/// Words the user selects and copies - an address, a code - and words they cannot.
struct SelectableTextSample: SampleContent, ExampleContent {
    static let id = "selectable-text"
    static let title = "Selectable text"
    static let summary = "Words the user can select and copy - an address, an order's code."

    // listing: SelectableTextSample
    /// Whether the address and the code can be selected, as the switch says.
    @State private var selectable = true

    var body: some View {
        VStack {
            Text("221B Baker Street, London NW1 6XE")
                .textStyle(.headline)
                .isSelectable(selectable)

            Text("Order 7F3K-92QX-L0MA")
                .isSelectable(selectable)

            Text("A caption the user only reads.")
                .textStyle(.caption)

            HStack {
                Switch($selectable)
                    .accessibilityIdentifier("selectable.on")
                    .accessibilityLabel("Selectable")

                Text("Selectable")
                    .verticalAlignment(.center)
            }
            .spacing(12)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Select the address or the code and copy it; turn the switch off and they no longer select.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
