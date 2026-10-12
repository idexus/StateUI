import StateUI

/// A stack holding a field, taking the arrows and Escape while the field holds the keyboard.
struct KeyPressSample: SampleContent, ExampleContent {
    // listing: KeyPressSample
    @State private var query = ""
    @State private var row = 0
    // listing: end

    static let id = "keyPress"
    static let title = "Key presses"
    static let summary = "Keys a view takes while it holds the keyboard, or holds the view that does."

    // listing: KeyPressSample
    var body: some View {
        VStack {
            Text("Type in the field: the arrows move through the list, and Escape empties the field.")
                .fontSize(14)

            VStack {
                TextField($query)
                    .placeholder("Search")

                Text(row == 0 ? "▸ Apples" : "Apples")
                Text(row == 1 ? "▸ Bread" : "Bread")
                Text(row == 2 ? "▸ Cheese" : "Cheese")
            }
            .spacing(6)
            // The stack holds the field, so these keys are its while the field holds the keyboard.
            .onKeyPressed(.upArrow, .downArrow, .escape) { key in
                if key == .escape {
                    query = ""
                } else {
                    row = min(2, max(0, row + (key == .upArrow ? -1 : 1)))
                }
            }
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("The field never sees the keys the stack takes; every other key types as before.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
