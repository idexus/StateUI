// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A question for the user answers as its buttons say, a prompt with the words typed, Escape as cancelling.
@MainActor
final class WebQuestionTests: XCTestCase {
    private var told: [(Bool, String?)] = []

    /// Asks `question`, and answers with the dialog the page then shows, the question held the while - as its owner
    /// holds it until it is answered.
    private func ask(_ question: HostQuestion, _ answer: (Int32) -> Void) {
        let asked = WebQuestion(question) { [unowned self] in told.append(($0, $1)) }
        asked.show()
        withExtendedLifetime(asked) { answer(WebPage.children(of: WebRelay.body)[0]) }
    }

    private func question(_ act: Act, _ arguments: [HostValue]) -> HostQuestion {
        HostQuestion(HostActCall(act: act, arguments: arguments, completion: nil))!
    }

    /// The button named as accepting answers yes; the one cancelling, no.
    func testAConfirmationAnswersByItsButtons() {
        let confirm = question(
            .confirm, [.string("Delete draft?"), .string("Gone for good"), .string("Delete"), .string("Keep")])
        ask(confirm) { dialog in
            let buttons = WebPage.children(of: WebPage.children(of: dialog).last!)
            XCTAssertEqual(buttons.map(WebPage.text), ["Keep", "Delete"])
            WebPage.tap(buttons[1])
        }
        XCTAssertEqual(told.map(\.0), [true])
    }

    /// A prompt accepted answers with the words its field holds.
    func testAPromptAnswersWithTheWordsTyped() {
        let prompt = question(.prompt, [.string("Rename"), .string("A new name"), .string("OK"), .string("Cancel")])
        ask(prompt) { dialog in
            let parts = WebPage.children(of: dialog)
            WebPage.enter("Paweł", into: parts[2])
            WebPage.tap(WebPage.children(of: parts[3])[1])
        }
        XCTAssertEqual(told.map(\.1), ["Paweł"])
    }

    /// Escape cancels a question that can be cancelled, and dismisses an alert.
    func testEscapeCancels() {
        ask(question(.confirm, [.string("Sure?")])) { WebPage.dismiss($0) }
        ask(question(.alert, [.string("Saved")])) { WebPage.dismiss($0) }
        XCTAssertEqual(told.map(\.0), [false, true])
    }
}
