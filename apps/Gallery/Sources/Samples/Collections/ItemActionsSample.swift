import StateUI

/// Mail whose items offer their actions: a swipe on a phone or a tablet, a context menu everywhere.
private struct MailList: ExampleContent {
    // listing: MailList
    @State private var mail = ["Lunch on Friday?", "Your order shipped", "Weekly notes", "Old news"]
    @State private var archived = 0

    var body: some View {
        Grid {
            Text("\(archived) archived")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(0)

            ItemsView(mail, id: \.self) { message in
                Text(message)
                    .fontSize(14)
                    .padding(horizontal: 14, vertical: 12)
                    // The item's actions, written once: a swipe where the platform swipes a list's items.
                    .contextMenu {
                        MenuItem("Archive").onClicked {
                            mail.removeAll { $0 == message }
                            archived += 1
                        }
                        MenuItem("Delete").role(.destructive).onClicked { mail.removeAll { $0 == message } }
                    }
            }
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Swipe an item left, or open its context menu.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// A list's items and the actions on each.
struct ItemActionsSample: SampleContent {
    static let id = "itemActions"
    static let title = "Item actions"
    static let summary = "An item's context menu is its actions - swiped to where the platform swipes a list's items."

    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [Example(MailList())]
    }
}
