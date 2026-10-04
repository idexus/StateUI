// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One question for the user in AppKit's own alert - its buttons, a choice's dangerous one marked, a prompt's field -
/// shown as a sheet on the window it is asked in, and answered once, whichever button the user presses.
/// Design: docs/design/platforms/appkit/runtime.md#questions-for-the-user
@MainActor
final class AppKitQuestion {
    /// The question as the host layer reads it.
    let question: HostQuestion

    /// The window it is asked in.
    weak var window: NSWindow?

    let alert = NSAlert()
    private let field = NSTextField(string: "")
    private var answer: ((_ accepted: Bool, _ words: String?) -> Void)?

    /// Each button's caption and what pressing it answers, in the order AppKit shows them.
    private var buttons: [(caption: String, accepts: Bool)] = []

    init(_ question: HostQuestion, in window: NSWindow) {
        self.question = question
        self.window = window
        alert.messageText = question.title ?? ""
        alert.informativeText = question.message ?? ""

        switch question.kind {
        case .alert:
            add(question.accept, accepts: true)
        case .confirm, .prompt:
            add(question.accept, accepts: true)
            add(question.cancel ?? "Cancel", accepts: false)
        case .chooseAction:
            // A choice answers the caption pressed, its cancel included.
            for choice in question.choices { add(choice, accepts: true) }
            if let destruction = question.destruction {
                add(destruction, accepts: true)
                alert.buttons.last?.hasDestructiveAction = true
            }
            if let cancel = question.cancel { add(cancel, accepts: true) }
        }

        if question.kind == .prompt {
            field.stringValue = question.words
            field.placeholderString = question.placeholder
            field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
            alert.accessoryView = field
        }
    }

    private func add(_ caption: String, accepts: Bool) {
        alert.addButton(withTitle: caption)
        buttons.append((caption, accepts))
    }

    /// Shows the question as a sheet on its window where `presents`, else holds it unshown; `answer` hears the
    /// user's answer once.
    func ask(presenting presents: Bool, answer: @escaping (_ accepted: Bool, _ words: String?) -> Void) {
        self.answer = answer
        guard presents, let window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in self?.respond(response) }
        if question.kind == .prompt { alert.window.makeFirstResponder(field) }
    }

    /// The button at `response` was pressed: accepted or not, and the words - the caption a choice pressed, the
    /// words a prompt holds, which the host layer cuts to its bound.
    private func respond(_ response: NSApplication.ModalResponse) {
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard buttons.indices.contains(index), let answer else { return }
        self.answer = nil

        let pressed = buttons[index]
        let words: String? = switch question.kind {
        case .chooseAction: pressed.caption
        case .prompt: field.stringValue
        case .alert, .confirm: nil
        }
        answer(pressed.accepts, words)
    }

    /// The question as it shows: its title, its message, its buttons' captions and a prompt's words.
    var shownForTesting: (title: String, message: String, buttons: [String], field: String?) {
        (alert.messageText, alert.informativeText, buttons.map(\.caption),
         question.kind == .prompt ? field.stringValue : nil)
    }

    /// Presses the button captioned `caption`, `typing` put in a prompt's field first, as the user does.
    func pressForTesting(_ caption: String, typing: String?) -> Bool {
        guard let index = buttons.firstIndex(where: { $0.caption == caption }) else { return false }
        if let typing { field.stringValue = typing }
        let response = NSApplication.ModalResponse(
            rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + index)
        if let parent = alert.window.sheetParent {
            parent.endSheet(alert.window, returnCode: response)
        } else {
            respond(response)
        }
        return true
    }
}

#endif
