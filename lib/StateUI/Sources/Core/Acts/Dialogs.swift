// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Dialogs: questions for the user, asked as acts - the handler suspends until the
// user answers.
// Design: docs/design/core/acts.md#dialogs

/// Questions for the user - an alert, a confirmation, a choice among actions and
/// a prompt - asked of the page that is showing. Each suspends the handler until
/// the user answers.
public enum Dialogs {
    /// Tells the user something, with one button to dismiss it.
    ///
    ///     try await Dialogs.alert("Saved", message: "The draft is safe")
    ///
    /// Suspends until the button is pressed, so the next line runs with the
    /// alert already gone.
    ///
    /// - Parameters:
    ///   - title: what the alert is about, in bold.
    ///   - message: the sentence under it.
    ///   - cancel: the one button's caption.
    /// - Throws: `StateUIError` when there is no page on screen to show it.
    public static nonisolated(nonsending) func alert(
        _ title: String,
        message: String,
        cancel: String = "OK"
    ) async throws {
        try await stateUICall(ApplicationContract.alert, title, message, cancel)
    }

    /// Asks the user a yes-or-no question.
    ///
    ///     let ok = try await Dialogs.confirm(
    ///         "Delete draft?", message: "This cannot be undone",
    ///         accept: "Delete", cancel: "Keep")
    ///     if ok { drafts.remove(draft) }
    ///
    /// - Parameters:
    ///   - title: the question, in bold.
    ///   - message: the sentence under it.
    ///   - accept: the caption of the button that answers yes.
    ///   - cancel: the caption of the button that answers no.
    /// - Returns: true when `accept` was pressed.
    /// - Throws: `StateUIError` when there is no page on screen to show it.
    public static nonisolated(nonsending) func confirm(
        _ title: String,
        message: String,
        accept: String,
        cancel: String
    ) async throws -> Bool {
        try await stateUICall(ApplicationContract.confirm, title, message, accept, cancel)
    }

    /// Offers the user a list of things to do.
    ///
    ///     let choice = try await Dialogs.chooseAction(
    ///         "Share via", cancel: "Cancel", buttons: ["Mail", "Message"])
    ///
    /// What comes back is the pressed caption - `cancel` and `destruction`
    /// included - so a `switch` over the same strings is the whole handling.
    ///
    /// - Parameters:
    ///   - title: what the choice is about.
    ///   - cancel: the dismissing button, drawn apart on iOS. Nil for none.
    ///   - destruction: the dangerous one, drawn red on iOS. Nil for none.
    ///   - buttons: the choices themselves, in order.
    /// - Returns: the pressed caption, or nil when the sheet was dismissed
    ///   without choosing - tapping beside it, where the platform allows that.
    /// - Throws: `StateUIError` when there is no page on screen to show it.
    public static nonisolated(nonsending) func chooseAction(
        _ title: String,
        cancel: String? = nil,
        destruction: String? = nil,
        buttons: [String]
    ) async throws -> String? {
        try await stateUICall(ApplicationContract.chooseAction, title, cancel, destruction, buttons)
    }

    /// Asks the user to type something.
    ///
    ///     let name = try await Dialogs.prompt(
    ///         "Rename", message: "A new name for the draft",
    ///         placeholder: "Name", initialValue: draft.name)
    ///     if let name { draft.name = name }
    ///
    /// - Parameters:
    ///   - title: what is being asked for, in bold.
    ///   - message: the sentence under it.
    ///   - accept: the confirming button's caption.
    ///   - cancel: the dismissing button's caption.
    ///   - placeholder: what the field says while it is empty. Nil for nothing.
    ///   - initialValue: what the field starts holding.
    ///   - maximumLength: how many characters the field accepts. Nil for no limit.
    ///   - inputPurpose: what the field is for, which picks the keyboard the
    ///     platform offers.
    /// - Returns: what was typed when `accept` was pressed - empty included,
    ///   which is an answer - or nil when the prompt was cancelled.
    /// - Throws: `StateUIError` when there is no page on screen to show it.
    public static nonisolated(nonsending) func prompt(
        _ title: String, message: String = "",
        accept: String = "OK", cancel: String = "Cancel",
        placeholder: String? = nil, initialValue: String = "",
        maximumLength: Int? = nil, inputPurpose: InputPurpose = .default
    ) async throws -> String? {
        try await stateUICall(
            ApplicationContract.prompt, title, message, accept, cancel, placeholder, maximumLength,
            inputPurpose, initialValue)
    }
}
