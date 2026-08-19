import StateUI

/// The item is a row's identity - what keeps a control across a change to
/// the list around it, and what a written `.id()` overrides.
struct IdentitySample: SampleContent {
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var nextItem = 1

    static let id = "identity"
    static let title = "Identity and reuse"
    static let summary = "Same identity, same control - which is what keeps focus, caret and scroll."

    static let code = """
        @State var items = ["Alpha", "Beta", "Gamma"]
        @State private var nextItem = 1

        VStack {
            HStack {
                Button("Add")
                    .onClicked {
                        items.append("Item \\(nextItem)")
                        nextItem += 1
                    }

                Button("Insert at the top")
                    .onClicked {
                        items.insert("Item \\(nextItem)", at: 0)
                        nextItem += 1
                    }

                Button("Rotate")
                    .isEnabled(items.count > 1)
                    .onClicked {
                        items = Array(items.dropFirst()) + [items[0]]
                    }
            }

            // Each row is identified by its ITEM - ForEach's rule - so
            // inserting at the top MOVES the controls already on screen.
            VStack {
                ForEach(items) { item in
                    IdentityRow(item: item, items: $items)
                }
            }
        }

        private struct IdentityRow: ContentView {
            let item: String
            @Binding var items: [String]

            var content: Element {
                HStack {
                    Label(item)
                        .widthRequest(90)
                        .verticalOptions(.center)

                    Entry()
                        .placeholder("type here")
                        .horizontalOptions(.fill)

                    Button("Remove")
                        .onClicked {
                            items = items.filter { $0 != item }
                        }
                }
            }
        }
        """

    var content: Element {
        VStack {
            HStack {
                Button("Add")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        items.append("Item \(nextItem)")
                        nextItem += 1
                    }

                Button("Insert at the top")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        items.insert("Item \(nextItem)", at: 0)
                        nextItem += 1
                    }

                Button("Rotate")
                    .fontSize(13)
                    .padding(16, 6)
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
                ForEach(items) { item in
                    IdentityRow(item: item, items: $items)                    
                }
            }
            .spacing(6)

            Label("Type in a field, then insert a row above it: the text stays where it "
                + "is, because the control did.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// One row, with something worth keeping in it: what is typed lives in the
/// control, not in the tree.
private struct IdentityRow: ContentView {
    let item: String
    @Binding var items: [String]

    var content: Element {
        HStack {
            Label(item)
                .fontSize(15)
                .widthRequest(90)
                .verticalOptions(.center)

            Entry()
                .placeholder("type here")
                .horizontalOptions(.fill)

            Button("Remove")
                .fontSize(12)
                .padding(12, 6)
                .onClicked {
                    items = items.filter { $0 != item }
                }
        }
        .spacing(10)
    }
}
