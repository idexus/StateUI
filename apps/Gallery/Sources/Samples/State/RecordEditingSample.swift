import StateUI

// listing: RecordEditingSample
/// A row edited live: each field a state of its own, which the host carries.
@MainActor
private final class Todo {
    let id: Int
    @State var title: String
    @State var done = false

    init(id: Int, title: String) {
        self.id = id
        // The state made here: a wrapped property is not assigned in `init`.
        _title = State(wrappedValue: title)
    }
}

/// A row that borrows its fields whole.
private struct TodoRow: View {
    @Binding var title: String
    @Binding var done: Bool

    var body: some View {
        // The field takes what the check box leaves.
        Grid {
            CheckBox($done)
                .accessibilityLabel("Done")
            TextField($title)
                .accessibilityLabel("Todo")
                .gridColumn(1)
        }
        .columns(.auto, .fill)
        .columnSpacing(8)
    }
}

/// The rows of a class of states: typing writes that row's own state, and
/// nothing here is built again.
private struct LiveTodos: View {
    @State private var todos = [Todo(id: 1, title: "Milk"), Todo(id: 2, title: "Bread")]

    var body: some View {
        VStack {
            SectionTitle("A class of states")
            DebugInfoLabel()

            ForEach(todos, id: \.id) { todo in
                TodoRow(title: todo.$title, done: todo.$done)
            }
        }
        .spacing(8)
    }
}

/// A row kept as a value - what a file holds, or a scene keeps.
private struct Chore {
    let id: Int
    var title: String
    var done = false
}

/// The rows of a value: every control shows its value, and its event writes
/// the user's change into the whole list - which builds this again.
private struct KeptChores: View {
    @State private var chores = [Chore(id: 1, title: "Dishes"), Chore(id: 2, title: "Laundry", done: true)]
    @State private var chosen: Int? = 1
    @State private var refreshing = false

    var body: some View {
        Grid {
            VStack {
                SectionTitle("A value and its event")
                DebugInfoLabel()
            }
            .spacing(8)
            .gridRow(0)

            ItemsView(chores, id: \.id) { chore in
                Text(chore.done ? "\(chore.title) ✓" : chore.title)
                    .padding(horizontal: 14, vertical: 10)
            }
            .selection($chosen)
            .isRefreshing($refreshing)
            .onRefreshRequested(.ignoreWhileRunning) {
                defer { refreshing = false }
                try await Task.sleep(for: .seconds(1))
            }
            .gridRow(1)

            VStack {
                if let chore = chores.first(where: { $0.id == chosen }) {
                    TextField(chore.title)
                        .accessibilityLabel("Chore")
                        .onTextChanged { title in edit(chore.id) { $0.title = title } }

                    CheckBox(chore.done)
                        .text("Done")
                        .onToggled { done in edit(chore.id) { $0.done = done } }
                }
            }
            .spacing(8)
            .gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        .rowSpacing(10)
    }

    /// The chore of `id`, changed in place - found by its identity, never by
    /// where it stands.
    private func edit(_ id: Int, _ change: (inout Chore) -> Void) {
        if let row = chores.firstIndex(where: { $0.id == id }) { change(&chores[row]) }
    }
}
// listing: end

/// One record edited two ways: a class whose fields are states, carried by the
/// host, and a value whose controls write it from their events.
struct RecordEditingSample: SampleContent, ExampleContent {
    static let id = "recordEditing"
    static let title = "Editing a record"
    static let summary = "A record edited live as a class of states, or kept as a value and written from each control's event."

    // The list is moved by a hand of its own, so the example is not put in a
    // scroller, and it takes the whole cell.
    static let scrolls = false
    static let fills = true

    // listing: RecordEditingSample
    var body: some View {
        Grid {
            LiveTodos()
                .gridRow(0)

            KeptChores()
                .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(16)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Type in a todo: its counter stands. Type in a chore or choose another: its counter moves.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A todo's fields are states of its own, handed to the controls whole; a chore is a value, "
                + "each control given its field and the change written by its event, by the chore's identity.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
