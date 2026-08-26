import StateUI

/// MAUI: Page.DisplayAlertAsync, DisplayActionSheetAsync and DisplayPromptAsync.
struct DialogsSample: SampleContent {
    @State private var answer = "nothing asked yet"
    @State private var name = "Draft 1"

    static let id = "dialogs"
    static let title = "Dialogs"
    static let summary = "An alert, an action sheet and a prompt - asked, awaited, answered."

    static let code = """
        @State private var answer = "nothing asked yet"
        @State private var name = "Draft 1"

        VStack {
            // One button, nothing to answer: the handler resumes when it is
            // dismissed, so the next line runs with the alert already gone.
            Button("Tell me something")
                .onClicked {
                    try await Dialogs.displayAlert(
                        "Saved", message: "The draft is safe")
                    answer = "the alert was dismissed"
                }

            // Ask, await, branch - in one place, which is what an act is for.
            Button("Ask me a question")
                .onClicked {
                    let ok = try await Dialogs.displayAlert(
                        "Delete draft?", message: "This cannot be undone",
                        accept: "Delete", cancel: "Keep")
                    answer = ok ? "Delete pressed" : "Keep pressed"
                }

            // The answer is the pressed CAPTION, cancel and destruction
            // included - nil only when the sheet was dismissed with nothing
            // chosen, tapping beside it where the platform allows that.
            Button("Offer me choices")
                .onClicked {
                    let choice = try await Dialogs.displayActionSheet(
                        "Share via", cancel: "Cancel", destruction: "Delete",
                        buttons: ["Mail", "Message"])
                    answer = choice.map { "\\($0) pressed" }
                        ?? "dismissed with nothing chosen"
                }

            // nil is CANCELLED; an accepted prompt with nothing typed comes
            // back as "" - an empty answer, which is still an answer.
            Button("Ask me to type")
                .onClicked {
                    let typed = try await Dialogs.displayPrompt(
                        "Rename", message: "A new name for the draft",
                        placeholder: "Name", initialValue: name, maxLength: 40)
                    if let typed { name = typed }
                    answer = typed.map { "renamed to '\\($0)'" } ?? "cancelled"
                }

            Label(answer)
            Label("the draft is called '\\(name)'")
        }
        """

    var content: Element {
        VStack {
            Button("Tell me something")
                .onClicked {
                    try await Dialogs.displayAlert(
                        "Saved", message: "The draft is safe")
                    answer = "the alert was dismissed"
                }

            Button("Ask me a question")
                .onClicked {
                    let ok = try await Dialogs.displayAlert(
                        "Delete draft?", message: "This cannot be undone",
                        accept: "Delete", cancel: "Keep")
                    answer = ok ? "Delete pressed" : "Keep pressed"
                }

            Button("Offer me choices")
                .onClicked {
                    let choice = try await Dialogs.displayActionSheet(
                        "Share via", cancel: "Cancel", destruction: "Delete",
                        buttons: ["Mail", "Message"])
                    answer = choice.map { "\($0) pressed" }
                        ?? "dismissed with nothing chosen"
                }

            Button("Ask me to type")
                .onClicked {
                    let typed = try await Dialogs.displayPrompt(
                        "Rename", message: "A new name for the draft",
                        placeholder: "Name", initialValue: name, maxLength: 40)
                    if let typed { name = typed }
                    answer = typed.map { "renamed to '\($0)'" } ?? "cancelled"
                }

            Label(answer)
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label("the draft is called '\(name)'")
                .fontSize(14)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A dialog is an ACT, not a view: the handler suspends while it is up "
                + "and resumes with the answer, which is MAUI's own shape - "
                + "await DisplayAlertAsync. The host shows it on the page that is "
                + "showing, the modal top included.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An action sheet answers with the pressed caption, cancel and "
                + "destruction included. A prompt answers nil when cancelled - an "
                + "accepted empty answer is \"\", which is not the same thing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
