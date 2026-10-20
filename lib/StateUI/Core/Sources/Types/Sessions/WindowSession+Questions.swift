// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window's questions for the user, asked as acts over that window - the handler suspends until the user answers.
// Design: docs/design/core/acts.md#dialogs

extension WindowSession {
    /// Tells the user something over this window, with one button to dismiss it.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     Button("Save").onClicked(gate: .ignoreWhileRunning) {
    ///         try await window.alert("Saved", message: "The draft is safe")
    ///     }
    ///
    /// Suspends until the button is pressed, so the next line runs with the
    /// alert already gone.
    ///
    /// - Parameters:
    ///   - title: what the alert is about, in bold.
    ///   - message: the sentence under it.
    ///   - cancel: the one button's caption; nil says "OK" in the system's language, as the platform's own
    ///     buttons do.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func alert(_ title: String, message: String, cancel: String? = nil) async throws {
        let (scene, window) = try address
        let words = await LibraryWords.inSystemLanguage
        try await stateUICall(ApplicationContract.alert, scene, window, title, message, cancel ?? words.ok)
    }

    /// Asks the user a yes-or-no question over this window.
    ///
    ///     let ok = try await window.confirm(
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
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func confirm(_ title: String, message: String, accept: String, cancel: String) async throws -> Bool {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.confirm, scene, window, title, message, accept, cancel)
    }

    /// Offers the user a list of things to do, over this window.
    ///
    ///     let choice = try await window.chooseAction(
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
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func chooseAction(
        _ title: String, cancel: String? = nil, destruction: String? = nil, buttons: [String]
    ) async throws -> String? {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.chooseAction, scene, window, title, cancel, destruction, buttons)
    }

    /// Asks the user to type something, over this window.
    ///
    ///     let name = try await window.prompt(
    ///         "Rename", message: "A new name for the draft",
    ///         placeholder: "Name", initialValue: draft.name)
    ///     if let name { draft.name = name }
    ///
    /// - Parameters:
    ///   - title: what is being asked for, in bold.
    ///   - message: the sentence under it.
    ///   - accept: the confirming button's caption; nil says "OK" in the system's language.
    ///   - cancel: the dismissing button's caption; nil says "Cancel" in the system's language.
    ///   - placeholder: what the field says while it is empty. Nil for nothing.
    ///   - initialValue: what the field starts holding.
    ///   - maximumLength: how many characters the field accepts. Nil for no limit.
    ///   - inputPurpose: what the field is for, which picks the keyboard the
    ///     platform offers.
    /// - Returns: what was typed when `accept` was pressed - empty included,
    ///   which is an answer - or nil when the prompt was cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func prompt(
        _ title: String, message: String = "",
        accept: String? = nil, cancel: String? = nil,
        placeholder: String? = nil, initialValue: String = "",
        maximumLength: Int? = nil, inputPurpose: InputPurpose = .default
    ) async throws -> String? {
        let (scene, window) = try address
        let words = await LibraryWords.inSystemLanguage
        return try await stateUICall(
            ApplicationContract.prompt, scene, window, title, message, accept ?? words.ok, cancel ?? words.cancel,
            placeholder, maximumLength, inputPurpose, initialValue)
    }
}
