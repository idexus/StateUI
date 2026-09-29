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
final class UIKitQuestion {
    /// The question as the host layer reads it.
    let question: HostQuestion

    let alert: UIAlertController
    private var answer: ((_ accepted: Bool, _ words: String?) -> Void)?

    /// Each button's caption and what pressing it answers, in the order UIKit shows them.
    private(set) var buttons: [(caption: String, accepts: Bool)] = []

    init(_ question: HostQuestion) {
        self.question = question
        alert = UIAlertController(
            title: question.title, message: question.message,
            preferredStyle: question.kind == .chooseAction ? .actionSheet : .alert)

        switch question.kind {
        case .alert:
            add(question.accept, accepts: true, style: .default)
        case .confirm, .prompt:
            add(question.cancel ?? "Cancel", accepts: false, style: .cancel)
            add(question.accept, accepts: true, style: .default)
        case .chooseAction:
            // A choice answers the caption pressed, its cancel included.
            for choice in question.choices { add(choice, accepts: true, style: .default) }
            if let destruction = question.destruction { add(destruction, accepts: true, style: .destructive) }
            if let cancel = question.cancel { add(cancel, accepts: true, style: .cancel) }
        }
        if question.kind == .prompt {
            alert.addTextField { field in
                field.text = question.words
                field.placeholder = question.placeholder
                UIKitKeyboard(spellChecked: true, predicted: true, purpose: question.purpose).apply(to: field)
            }
        }
    }

    private func add(_ caption: String, accepts: Bool, style: UIAlertAction.Style) {
        let index = buttons.count
        buttons.append((caption, accepts))
        alert.addAction(UIAlertAction(title: caption, style: style) { [weak self] _ in self?.respond(index) })
    }

    /// Presents the question over `presenter`; `answer` hears the user's answer, once.
    func ask(over presenter: UIViewController, answer: @escaping (_ accepted: Bool, _ words: String?) -> Void) {
        self.answer = answer
        if let popover = alert.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(alert, animated: true)
    }

    /// The button at `index` was pressed.
    private func respond(_ index: Int) {
        let (caption, accepts) = buttons[index]
        let words = question.kind == .chooseAction ? caption : alert.textFields?.first?.text
        answer?(accepts, words)
        answer = nil
    }

    /// Presses the button captioned `caption`, `typing` put in a prompt's field first, as the user does: the alert
    /// goes, and the button's own handler runs.
    func press(_ caption: String, typing: String?) -> Bool {
        guard let index = buttons.firstIndex(where: { $0.caption == caption }) else { return false }
        if let typing { alert.textFields?.first?.text = typing }
        alert.presentingViewController?.dismiss(animated: false)
        respond(index)
        return true
    }
}
#endif
