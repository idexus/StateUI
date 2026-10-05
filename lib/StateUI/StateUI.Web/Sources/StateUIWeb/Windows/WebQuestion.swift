// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A question for the user in the browser's own modal `<dialog>`: its title and message, the words a prompt asks
/// for, and a button for each answer - a choice's actions one under another, its dangerous one marked; Escape
/// answers as cancelling does, where the question can be cancelled.
/// Design: docs/design/platforms/web/pages.md#questions-for-the-user
@MainActor
final class WebQuestion {
    private let dialog = WebDOMView(tag: "dialog")
    private var parts: [WebDOMView] = []
    private var field: WebTextInputView?
    private var answered: ((Bool, String?) -> Void)?

    init(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) {
        self.answered = answered
        dialog.attribute("class", "stateui-question")
        dialog.attribute("data-kind", question.kind == .chooseAction ? "choice" : nil)
        if let title = question.title, !title.isEmpty { add("h2", title) }
        if let message = question.message, !message.isEmpty { add("p", message) }
        if question.kind == .prompt { addField(question) }

        let buttons = WebDOMView(tag: "div")
        buttons.attribute("class", "stateui-question-buttons")
        insert(buttons)
        var index = 0
        func button(_ words: String, role: String?, answer: @escaping (WebQuestion) -> Void) {
            let made = WebDOMView(tag: "button")
            made.attribute("type", "button")
            made.attribute("data-role", role)
            WebRelay.setText(made.node, words)
            made.listen("click") { [weak self] in if let self { answer(self) } }
            WebRelay.insert(made.node, into: buttons.node, at: index)
            parts.append(made)
            index += 1
        }
        switch question.kind {
        case .chooseAction:
            for choice in question.choices { button(choice, role: nil) { $0.answer(true, choice) } }
            if let destruction = question.destruction {
                button(destruction, role: "destructive") { $0.answer(true, destruction) }
            }
            // A choice's cancel is a choice of its caption; dismissed - Escape - nothing was chosen.
            if let cancel = question.cancel { button(cancel, role: "cancel") { $0.answer(true, cancel) } }
        default:
            if let cancel = question.cancel { button(cancel, role: "cancel") { $0.answer(false, nil) } }
            button(question.accept, role: "accept") { $0.answer(true, $0.typed) }
        }
        let cancels = question.kind != .alert && (question.kind != .chooseAction || question.cancel != nil)
        dialog.listen("dismiss") { [weak self] in
            guard let self else { return }
            if question.kind == .alert {
                answer(true, nil)
            } else if cancels {
                answer(false, nil)
            }
        }
    }

    /// Shows the question over the page.
    func show() {
        WebRelay.insert(dialog.node, into: WebRelay.body, at: 0)
        WebRelay.showModal(dialog.node)
        if let field { _ = WebRelay.focus(field.node) }
    }

    /// The words the prompt's field holds.
    private var typed: String? {
        field.map { WebRelay.value(of: $0.node) }
    }

    private func answer(_ accepted: Bool, _ words: String?) {
        guard let answered else { return }
        self.answered = nil
        WebRelay.closeModal(dialog.node)
        for part in parts { part.detach() }
        field?.detach()
        dialog.detach()
        answered(accepted, words)
    }

    private func add(_ tag: String, _ words: String) {
        let part = WebDOMView(tag: tag)
        WebRelay.setText(part.node, words)
        insert(part)
    }

    private func addField(_ question: HostQuestion) {
        let field = WebTextInputView(.field)
        field.setTraits(InputTraits(spellChecked: true, predicted: true, purpose: question.purpose))
        field.setPlaceholder(question.placeholder)
        field.attribute("maxlength", question.maximumLength.map(String.init))
        WebRelay.setValue(field.node, question.words)
        field.listen("enter") { [weak self] in
            guard let self else { return }
            answer(true, typed)
        }
        WebRelay.insert(field.node, into: dialog.node, at: parts.count)
        self.field = field
    }

    private func insert(_ part: WebDOMView) {
        WebRelay.insert(part.node, into: dialog.node, at: parts.count + (field == nil ? 0 : 1))
        parts.append(part)
    }
}
