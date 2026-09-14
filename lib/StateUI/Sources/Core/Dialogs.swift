// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Asking the reader a question.
//
// A dialog is not a shape, so it is not in the tree - it is an ACT, and it
// goes through Command.swift exactly as focusing a field or scrolling a list
// does:
//
//     let ok = try await Dialogs.displayAlert(
//         "Delete draft?", message: "This cannot be undone",
//         accept: "Delete", cancel: "Keep")
//
// The handler suspends while the dialog is up and resumes with the answer,
// which is the reason this is not a modifier with a binding: asking, waiting
// and branching is one sequential thought, and an act keeps it in one place
// where a binding would split it into a state write here and a result closure
// there.
//
// None of these names a page: a handler holds a description of a page rather
// than the page, so the host shows the dialog on the page the reader is
// actually looking at - the top of the modal stack included, which only the
// host can know. `SoftInput` is the same shape of answer for the keyboard.

/// Questions for the reader - an alert, a choice among actions and a prompt,
/// asked of the page that is showing. Each suspends the handler until the
/// reader answers.
public enum Dialogs {
    /// Tells the reader something, with one button to dismiss it.
    ///
    ///     try await Dialogs.displayAlert("Saved", message: "The draft is safe")
    ///
    /// Suspends until the button is pressed, so the next line runs with the
    /// alert already gone.
    ///
    /// - Parameters:
    ///   - title: what the alert is about, in bold.
    ///   - message: the sentence under it.
    ///   - cancel: the one button's caption.
    /// - Throws: `StateUIError` when there is no page on screen to show it.
    public static nonisolated(nonsending) func displayAlert(
        _ title: String,
        message: String,
        cancel: String = "OK"
    ) async throws {
        try await stateUICall(
            .displayAlertAsync,
            [.string(title), .string(message), .string(cancel)])
    }

    /// Asks the reader a yes-or-no question.
    ///
    ///     let ok = try await Dialogs.displayAlert(
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
    public static nonisolated(nonsending) func displayAlert(
        _ title: String,
        message: String,
        accept: String,
        cancel: String
    ) async throws -> Bool {
        try await stateUICall(
            .displayAlertAsync,
            [.string(title), .string(message), .string(accept), .string(cancel)])
            .value()?.bool == true
    }

    /// Offers the reader a list of things to do.
    ///
    ///     let choice = try await Dialogs.displayActionSheet(
    ///         "Share via", cancel: "Cancel", buttons: ["Mail", "Message"])
    ///
    /// What comes back is the pressed CAPTION - `cancel` and `destruction`
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
    public static nonisolated(nonsending) func displayActionSheet(
        _ title: String,
        cancel: String? = nil,
        destruction: String? = nil,
        buttons: [String]
    ) async throws -> String? {
        chosen(try await stateUICall(
            .displayActionSheetAsync,
            [
                .string(title),
                cancel.map { PropValue.string($0) } ?? .nothing,
                destruction.map { PropValue.string($0) } ?? .nothing,
            ] + buttons.map { .string($0) }))
    }

    /// Asks the reader to type something. The arguments cross in the act's
    /// order, `initialValue` last; the Swift signature keeps it beside
    /// `placeholder`, where it reads.
    ///
    ///     let name = try await Dialogs.displayPrompt(
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
    public static nonisolated(nonsending) func displayPrompt(
        _ title: String, message: String = "",
        accept: String = "OK", cancel: String = "Cancel",
        placeholder: String? = nil, initialValue: String = "",
        maximumLength: Int? = nil, inputPurpose: InputPurpose = .default
    ) async throws -> String? {
        chosen(try await stateUICall(
            .displayPromptAsync,
            [
                .string(title), .string(message), .string(accept), .string(cancel),
                placeholder.map { PropValue.string($0) } ?? .nothing,
                maximumLength.map { PropValue.number(Double($0)) } ?? .nothing,
                inputPurpose.propValue, .string(initialValue),
            ]))
    }

    /// An answer that may be nothing: a choice crosses as one string value -
    /// empty included, which is an accepted prompt with nothing typed - and a
    /// dismissal crosses as the wire's own nothing, which reads as nil here.
    /// One value either way, so the SHAPE of the reply says nothing about the
    /// answer. See `Wire.decodeReply`.
    private static func chosen(_ reply: [PropValue]) -> String? {
        reply.value()?.string
    }
}
