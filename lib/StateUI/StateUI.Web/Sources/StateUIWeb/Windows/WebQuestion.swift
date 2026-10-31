// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A question for the user in the browser's own modal `<dialog>`: its title and message, the words a prompt asks
/// for, and a button for each answer, named by what it answers (`data-answer`) - a choice's actions one under
/// another, its dangerous one marked; Escape answers as cancelling does, an alert's as its one button.
/// Design: docs/design/platforms/web/pages.md#questions-for-the-user
@MainActor
final class WebQuestion {
    private let dialog = WebDOMView(tag: "dialog")
    private var parts: [WebDOMView] = []
    private var field: WebTextInputView?
    private var answered: ((HostQuestion.Given) -> Void)?

    init(_ question: HostQuestion, answered: @escaping (HostQuestion.Given) -> Void) {
        self.answered = answered
        dialog.attribute("class", "stateui-question")
        dialog.attribute("data-kind", question.kind == .chooseAction ? "choice" : nil)
        if let title = question.title, !title.isEmpty { add("h2", title) }
        if let message = question.message, !message.isEmpty { add("p", message) }
        if question.kind == .prompt { addField(question) }

        let buttons = WebDOMView(tag: "div")
        buttons.attribute("class", "stateui-question-buttons")
        insert(buttons)
        // A choice's actions stand first, its cancel last; a confirmation's and a prompt's cancel before the accept.
        let offered = question.buttons
        let ordered = question.kind == .chooseAction
            ? offered : offered.filter { $0.role == .cancel } + offered.filter { $0.role != .cancel }
        for (index, (caption, role)) in ordered.enumerated() {
            let made = WebDOMView(tag: "button")
            made.attribute("type", "button")
            made.attribute("data-answer", Self.answer(of: role))
            let look: String? = switch role {
            case .accept: "accept"
            case .cancel: "cancel"
            case .action(let place): place == question.destructive ? "destructive" : nil
            }
            made.attribute("data-role", look)
            WebRelay.setText(made.node, caption)
            made.listen("click") { [weak self] in
                guard let self else { return }
                answer(HostQuestion.Given(pressed: role, typing: typed))
            }
            WebRelay.insert(made.node, into: buttons.node, at: index)
            parts.append(made)
        }
        dialog.hear(.dismiss) { [weak self] in
            self?.answer(HostQuestion.Given(pressed: question.kind == .alert ? .accept : .cancel))
        }
    }

    /// What a button doing `button` is named by: `accept`, `cancel`, `action-<place>`.
    static func answer(of button: QuestionButton) -> String {
        switch button {
        case .accept: "accept"
        case .cancel: "cancel"
        case .action(let place): "action-\(place)"
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

    private func answer(_ given: HostQuestion.Given) {
        guard let answered else { return }
        withdraw()
        answered(given)
    }

    /// Takes the question away, answering nobody: the window it stood over went.
    func withdraw() {
        answered = nil
        WebRelay.closeModal(dialog.node)
        for part in parts { part.release() }
        field?.release()
        dialog.release()
    }

    private func add(_ tag: String, _ words: String) {
        let part = WebDOMView(tag: tag)
        WebRelay.setText(part.node, words)
        insert(part)
    }

    private func addField(_ question: HostQuestion) {
        let field = WebTextInputView(.field)
        field.setTraits(question.traits)
        field.setPlaceholder(question.placeholder)
        field.setMaximumLength(question.maximumLength)
        WebRelay.setValue(field.node, question.words)
        field.hear(.enter) { [weak self] in
            guard let self else { return }
            answer(HostQuestion.Given(accepted: true, words: typed))
        }
        WebRelay.insert(field.node, into: dialog.node, at: parts.count)
        self.field = field
    }

    private func insert(_ part: WebDOMView) {
        WebRelay.insert(part.node, into: dialog.node, at: parts.count + (field == nil ? 0 : 1))
        parts.append(part)
    }
}
