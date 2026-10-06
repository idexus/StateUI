import StateUI

/// The item is a row's identity - what keeps a control across a change to
/// the list around it, and what a written `.id()` overrides.
struct IdentitySample: SampleContent, ExampleContent {
    // listing: IdentitySample
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var nextItem = 1
    // listing: end

    static let id = "identity"
    static let title = "Identity and reuse"
    static let summary = "Same identity, same control - which is what keeps focus, caret and scroll."

    // listing: IdentitySample
    var body: some View {
        VStack {
            HStack {
                Button("Add")
                    .fontSize(13)
                    .padding(horizontal: 16, vertical: 6)
                    .onClicked {
                        items.append("Item \(nextItem)")
                        nextItem += 1
                    }

                Button("Insert at the top")
                    .fontSize(13)
                    .padding(horizontal: 16, vertical: 6)
                    .onClicked {
                        items.insert("Item \(nextItem)", at: 0)
                        nextItem += 1
                    }

                Button("Rotate")
                    .fontSize(13)
                    .padding(horizontal: 16, vertical: 6)
                    .isEnabled(items.count > 1)
                    .onClicked {
                        items = Array(items.dropFirst()) + [items[0]]
                    }
            }
            .spacing(10)

            // Each row is identified by its ITEM - ForEach's rule, and the
            // reason a plain `for` does not compile here: known by position,
            // an inserted row would rewrite every row into the one below it.
            // A row may still write `.id()` of its own, and the author's wins.
            VStack {
                // The list is described again on every change, and the rows
                // keep their controls through it - which is what identity is.
                DebugInfoLabel()

                ForEach(items) { item in
                    IdentityRow(item: item, items: $items)                    
                }
            }
            .spacing(6)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Type in a field, then insert a row above it: the text stays with its "
                + "row, because its control does.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A row is identified by its item, which is `ForEach`'s rule. Known by "
                + "position, an inserted row would rewrite every row into the one below "
                + "it, which is why a plain `for` does not compile here. A row may still "
                + "write an `.id()` of its own, and the author's wins.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

// listing: IdentitySample
/// One row, with something worth keeping in it: what is typed lives in the
/// control, not in the tree.
private struct IdentityRow: View {
    let item: String
    @Binding var items: [String]

    var body: some View {
        HStack {
            Text(item)
                .fontSize(15)
                .width(90)
                .verticalAlignment(.center)

            TextField()
                .accessibilityIdentifier("identity.typed")
                .accessibilityLabel("Anything typed here")
                .placeholder("type here")
                .horizontalAlignment(.fill)

            Button("Remove")
                .fontSize(12)
                .padding(horizontal: 12, vertical: 6)
                .onClicked {
                    items = items.filter { $0 != item }
                }
        }
        .spacing(10)
    }
}
// listing: end
