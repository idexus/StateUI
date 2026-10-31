// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One question for the user in UIKit's own alert - a choice as an action sheet, its dangerous caption marked, a
/// prompt with its field - presented over what the window shows, and answered once, whichever button the user
/// presses.
/// Design: docs/design/platforms/uikit/runtime.md#questions-for-the-user
@MainActor
final class UIKitQuestion: NSObject, UIPopoverPresentationControllerDelegate {
    /// The question as the host layer reads it.
    let question: HostQuestion

    let alert: UIAlertController
    private var answer: ((HostQuestion.Given) -> Void)?
    private weak var root: UIKitRootViewController?

    /// Each button's caption and what pressing it answers, in the order they were added; UIKit stands the cancel
    /// where its style puts it.
    private(set) var buttons: [(caption: String, role: QuestionButton)] = []

    init(_ question: HostQuestion) {
        self.question = question
        alert = UIAlertController(
            title: question.title, message: question.message,
            preferredStyle: question.kind == .chooseAction ? .actionSheet : .alert)
        super.init()
        alert.popoverPresentationController?.delegate = self

        for (caption, role) in question.buttons {
            let style: UIAlertAction.Style = switch role {
            case .cancel: .cancel
            case .action(let place) where place == question.destructive: .destructive
            case .accept, .action: .default
            }
            add(caption, role, style: style)
        }
        if question.kind == .prompt {
            alert.addTextField { field in
                field.text = question.words
                field.placeholder = question.placeholder
                UIKitKeyboard(question.traits).apply(to: field)
            }
        }
    }

    private func add(_ caption: String, _ role: QuestionButton, style: UIAlertAction.Style) {
        let index = buttons.count
        buttons.append((caption, role))
        alert.addAction(UIAlertAction(title: caption, style: style) { [weak self] _ in self?.respond(index) })
    }

    /// Presents the question through the window's `root`, which presents everything over it; `answer` hears the
    /// user's answer, once.
    func ask(in root: UIKitRootViewController, answer: @escaping (HostQuestion.Given) -> Void) {
        self.answer = answer
        self.root = root
        root.pass(alert)
    }

    /// The button at `index` was pressed: what it does, with the words a prompt's field holds.
    private func respond(_ index: Int) {
        answer?(HostQuestion.Given(pressed: buttons[index].role, typing: alert.textFields?.first?.text))
        answer = nil
        root?.passed(alert)
    }

    /// A choice standing as a popover, tapped away: nothing was chosen.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        answer?(.dismissed)
        answer = nil
        root?.passed(alert)
    }

    /// Presses the button doing `button`, `typing` put in a prompt's field first, as the user does: the alert goes,
    /// and the button's own handler runs.
    func press(_ button: QuestionButton, typing: String?) -> Bool {
        guard let index = buttons.firstIndex(where: { $0.role == button }) else { return false }
        if let typing { alert.textFields?.first?.text = typing }
        alert.presentingViewController?.dismiss(animated: false)
        respond(index)
        return true
    }
}
#endif
