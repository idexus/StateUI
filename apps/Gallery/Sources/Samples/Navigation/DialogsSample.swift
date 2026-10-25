import StateUI

/// Native alerts, confirmations, choices of actions and prompts, asked as awaited StateUI acts.
struct DialogsSample: SampleContent, ExampleContent {
    // listing: DialogsSample
    @Environment(\.window) private var window
    @State private var answer = "nothing asked yet"
    @State private var name = "Draft 1"

    /// What the draft can be done with.
    enum Share: CaseIterable {
        case mail, message, delete

        /// What each says on its button.
        var title: String {
            switch self {
            case .mail: "Mail"
            case .message: "Message"
            case .delete: "Delete"
            }
        }
    }
    // listing: end

    static let id = "dialogs"
    static let title = "Dialogs"
    static let summary = "An alert, a confirmation, a choice of actions and a prompt - asked, awaited, answered."

    // listing: DialogsSample
    var body: some View {
        VStack {
            // The answer is read here, so every dialog that closes builds
            // this closure.
            DebugInfoLabel()

            // One button, nothing to answer: the handler resumes when it is
            // dismissed, so the next line runs with the alert already gone.
            Button("Tell me something")
                .onClicked(.ignoreWhileRunning) {
                    try await window.alert(
                        "Saved", message: "The draft is safe")
                    answer = "the alert was dismissed"
                }

            // Ask, await, branch - in one place, which is what an act is for.
            // The cancel says the system's own word.
            Button("Ask me a question")
                .onClicked(.ignoreWhileRunning) {
                    let ok = try await window.confirm(
                        "Delete draft?", message: "This cannot be undone", accept: "Delete")
                    answer = ok ? "Delete pressed" : "cancelled"
                }

            // The answer is the action chosen, as a value - nil for the
            // cancel, or a sheet tapped away where the platform allows that.
            Button("Offer me choices")
                .onClicked(.ignoreWhileRunning) {
                    let choice = try await window.chooseAction(
                        "Share via", among: Share.allCases, caption: \.title, destructive: .delete)
                    answer = choice.map { "\($0.title) chosen" } ?? "nothing chosen"
                }

            // nil is CANCELLED; an accepted prompt with nothing typed comes
            // back as "" - an empty answer, which is still an answer.
            Button("Ask me to type")
                .onClicked(.ignoreWhileRunning) {
                    let typed = try await window.prompt(
                        "Rename", message: "A new name for the draft",
                        placeholder: "Name", initialValue: name, maximumLength: 40)
                    if let typed { name = typed }
                    answer = typed.map { "renamed to '\($0)'" } ?? "cancelled"
                }

            Text(answer)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Text("the draft is called '\(name)'")
                .fontSize(14)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A dialog is an act of the window that asks, not a view: it stands over "
                + "that window, and the handler resumes with the native answer after "
                + "the dialog closes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A choice of actions answers with the action chosen, or nil for its "
                + "cancel. A prompt answers nil when cancelled - an accepted empty answer "
                + "is \"\", which is not the same thing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
