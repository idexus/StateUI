// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window's questions for the user, asked as acts over that window - the handler suspends until the user answers.
// Design: docs/design/core/acts.md#dialogs

extension WindowSession {
    /// Tells the user something over this window, with one button to dismiss it.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     Button("Save").onClicked(.ignoreWhileRunning) {
    ///         try await window.alert("Saved", message: "The draft is safe")
    ///     }
    ///
    /// Suspends until the button is pressed, so the next line runs with the
    /// alert already gone.
    ///
    /// - Parameters:
    ///   - title: what the alert is about, in bold.
    ///   - message: the sentence under it.
    ///   - accept: the one button's caption; nil says "OK" in the system's language, as the platform's own
    ///     buttons do.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func alert(_ title: String, message: String, accept: String? = nil) async throws {
        let (scene, window) = try address
        let words = LibraryWords.inSystemLanguage
        try await stateUICall(ApplicationContract.alert, scene, window, title, message, accept ?? words.ok)
    }

    /// Asks the user a yes-or-no question over this window.
    ///
    ///     let ok = try await window.confirm(
    ///         "Delete draft?", message: "This cannot be undone", accept: "Delete")
    ///     if ok { drafts.remove(draft) }
    ///
    /// - Parameters:
    ///   - title: the question, in bold.
    ///   - message: the sentence under it.
    ///   - accept: the caption of the button that answers yes.
    ///   - cancel: the caption of the button that answers no; nil says "Cancel" in the system's language.
    /// - Returns: true when `accept` was pressed.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func confirm(
        _ title: String, message: String, accept: String, cancel: String? = nil
    ) async throws -> Bool {
        let (scene, window) = try address
        let words = LibraryWords.inSystemLanguage
        return try await stateUICall(
            ApplicationContract.confirm, scene, window, title, message, accept, cancel ?? words.cancel)
    }

    /// Offers the user a list of things to do, over this window, and answers the one they chose - here `Share`, an
    /// enum of the actions each saying its `title`:
    ///
    ///     let choice = try await window.chooseAction(
    ///         "Share via", among: Share.allCases, caption: \.title, destructive: .delete)
    ///     switch choice {
    ///     case .mail?: try await mail()
    ///     case .message?: try await message()
    ///     case .delete?: drafts.remove(draft)
    ///     case nil: break
    ///     }
    ///
    /// A choice always offers its cancel, which answers nil, as dismissing the
    /// choice does where the platform lets the user tap beside it.
    ///
    /// - Parameters:
    ///   - title: what the choice is about.
    ///   - choices: the actions offered, in order.
    ///   - caption: what each says; its description where nothing else is said.
    ///   - destructive: the dangerous one among them, drawn as the platform draws one. Nil for none.
    ///   - cancel: the dismissing button's caption; nil says "Cancel" in the system's language.
    /// - Returns: the action chosen, or nil where the choice was cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func chooseAction<Choice: Equatable>(
        _ title: String, among choices: [Choice], caption: (Choice) -> String = { "\($0)" },
        destructive: Choice? = nil, cancel: String? = nil
    ) async throws -> Choice? {
        let (scene, window) = try address
        let words = LibraryWords.inSystemLanguage
        let dangerous = destructive.flatMap { choices.firstIndex(of: $0) }
        let chosen = try await stateUICall(
            ApplicationContract.chooseAction, scene, window, title, choices.map(caption), dangerous,
            cancel ?? words.cancel)
        guard let chosen else { return nil }
        guard choices.indices.contains(chosen) else {
            throw StateUIError(message: "the host answered action \(chosen) of \(choices.count) offered")
        }
        return choices[chosen]
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
        let words = LibraryWords.inSystemLanguage
        return try await stateUICall(
            ApplicationContract.prompt, scene, window, title, message, accept ?? words.ok, cancel ?? words.cancel,
            placeholder, maximumLength, inputPurpose, initialValue)
    }
}
