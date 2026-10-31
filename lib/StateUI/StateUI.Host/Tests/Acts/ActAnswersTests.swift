// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host reads the acts it performs: what a question asks and answers, one question at a time, and the
/// element an act is aimed at.
@MainActor
final class ActAnswersTests: XCTestCase {
    /// A question's arguments stand where every host reads them; a caption the act leaves out is the standing one.
    func testAQuestionIsReadAsItsActWritesIt() throws {
        let confirm = try XCTUnwrap(HostQuestion(HostActCall(act: .confirm, arguments: HostActCall.usersWindow + [.string("Delete?")], completion: 1)))
        XCTAssertEqual(confirm.title, "Delete?")
        XCTAssertEqual(confirm.accept, "OK")
        XCTAssertEqual(confirm.cancel, "Cancel")
        XCTAssertEqual(confirm.cancelling, "Cancel", "a confirmation always offers its cancel")

        let choose = try XCTUnwrap(HostQuestion(HostActCall(
            act: .chooseAction,
            arguments: HostActCall.usersWindow + [.string("Share"), ["Mail", "Copy", "Delete"].propValue, .number(2)],
            completion: 2)))
        XCTAssertEqual(choose.cancelling, "Cancel", "a choice always offers its cancel")
        XCTAssertEqual(choose.choices, ["Mail", "Copy", "Delete"])
        XCTAssertEqual(choose.destructive, 2)
        let beyond = try XCTUnwrap(HostQuestion(HostActCall(
            act: .chooseAction, arguments: HostActCall.usersWindow + [.string("Share"), ["Mail"].propValue, .number(4)],
            completion: 2)))
        XCTAssertNil(beyond.destructive, "a dangerous place beyond the actions marks none")

        let prompt = try XCTUnwrap(HostQuestion(HostActCall(
            act: .prompt, arguments: HostActCall.usersWindow + [.string("Name"), .nothing, .nothing, .nothing, .string("Ada"), .number(8),
                                      InputPurpose.email.propValue, .string("ada@")], completion: 3)))
        XCTAssertEqual(prompt.placeholder, "Ada")
        XCTAssertEqual(prompt.maximumLength, 8)
        XCTAssertEqual(prompt.purpose, .email)
        XCTAssertEqual(prompt.words, "ada@")
        XCTAssertEqual(prompt.cancelling, "Cancel", "and so does a prompt")
        XCTAssertNil(HostQuestion(HostActCall(act: .announce, arguments: [], completion: nil)))
    }

    /// A prompt's field takes the typing of its purpose, as a field of that purpose does: a plain one checks no
    /// spelling, predicts nothing and writes no capitals.
    func testAPromptsFieldTypesForItsPurpose() throws {
        func prompt(_ purpose: InputPurpose) throws -> HostQuestion {
            try XCTUnwrap(HostQuestion(HostActCall(
                act: .prompt, arguments: HostActCall.usersWindow + [.string("Name"), .nothing, .nothing, .nothing, .nothing, .nothing,
                                          purpose.propValue], completion: 1)))
        }
        for purpose in [InputPurpose.default, .plain, .email, .numeric] {
            XCTAssertEqual(try prompt(purpose).traits, InputTraits(spellChecked: true, predicted: true, purpose: purpose))
        }
        XCTAssertFalse(try prompt(.plain).traits.checksSpelling)
    }

    /// A confirmation answers yes or no; a choice the place of an action it offers, a prompt its words, where the user
    /// accepted, nothing where not; an alert nothing.
    func testAQuestionAnswersAsItsKindDoes() throws {
        func question(_ act: Act) throws -> HostQuestion { try XCTUnwrap(HostQuestion(HostActCall(act: act, arguments: [], completion: 1))) }
        XCTAssertEqual(try question(.confirm).answer(.init(accepted: true)), [.bool(true)])
        XCTAssertEqual(try question(.prompt).answer(.init(accepted: true, words: "Ada")), ["Ada".propValue])
        XCTAssertEqual(try question(.prompt).answer(.init(accepted: false, words: "Ada")), [(nil as String?).propValue])
        XCTAssertEqual(try question(.alert).answer(.init(accepted: true)), [])

        let choose = try XCTUnwrap(HostQuestion(HostActCall(
            act: .chooseAction, arguments: HostActCall.usersWindow + [.string("Share"), ["Mail", "Copy"].propValue],
            completion: 3)))
        XCTAssertEqual(choose.answer(.init(chosen: 1)), [1.propValue])
        XCTAssertEqual(choose.answer(.init(chosen: 5)), [(nil as Int?).propValue], "no action of its offers nothing")
        XCTAssertEqual(choose.answer(.dismissed), [(nil as Int?).propValue])
        XCTAssertEqual(choose.answer(.init(pressed: .cancel)), [(nil as Int?).propValue], "its cancel offers nothing")
    }

    /// A question's buttons are what every host draws, each answering by what it does: an alert's one; a
    /// confirmation's and a prompt's accept, then the cancel; a choice's actions in order, then the cancel.
    func testAQuestionsButtonsAnswerByWhatTheyDo() throws {
        func question(_ act: Act, _ arguments: [HostValue]) throws -> HostQuestion {
            try XCTUnwrap(HostQuestion(HostActCall(act: act, arguments: HostActCall.usersWindow + arguments, completion: 1)))
        }
        func roles(_ question: HostQuestion) -> [String] { question.buttons.map { "\($0.caption) \($0.role)" } }
        XCTAssertEqual(roles(try question(.alert, [.string("Saved")])), ["OK accept"])
        XCTAssertEqual(
            roles(try question(.confirm, [.string("Delete?"), .nothing, .string("Delete"), .string("Keep")])),
            ["Delete accept", "Keep cancel"])
        XCTAssertEqual(
            roles(try question(.chooseAction, [.string("Share"), ["Mail", "Copy"].propValue, .nothing, .string("Back")])),
            ["Mail action(0)", "Copy action(1)", "Back cancel"])
        let prompt = try question(.prompt, [.string("Name"), .nothing, .string("Save"), .string("Back")])
        XCTAssertEqual(prompt.answer(.init(pressed: .accept, typing: "Ada")), ["Ada".propValue])
        XCTAssertEqual(prompt.answer(.init(pressed: .cancel, typing: "Ada")), [(nil as String?).propValue])

        let bounded = try XCTUnwrap(HostQuestion(HostActCall(
            act: .prompt, arguments: HostActCall.usersWindow + [.string("Name"), .nothing, .nothing, .nothing, .nothing, .number(3)], completion: 4)))
        XCTAssertEqual(bounded.answer(.init(accepted: true, words: "Adé👍x")), ["Adé".propValue], "cut to its bound, by characters")
    }

    /// Questions show one at a time, in the order asked; answering the one showing shows the next, and an answer
    /// under no waiting ticket answers nothing.
    func testQuestionsShowOneAtATime() throws {
        let queue = QuestionQueue<String>()
        let first = queue.ask("first")
        let second = queue.ask("second")
        XCTAssertTrue(first.showsNow)
        XCTAssertFalse(second.showsNow)

        let answered = try XCTUnwrap(queue.answered(first.ticket))
        XCTAssertEqual(answered.question, "first")
        XCTAssertEqual(answered.next, "second")
        XCTAssertNil(queue.answered(first.ticket))
    }

    /// Every question's ticket is its own across the process, whatever its queue asks: an answer under a ticket
    /// another queue gave - one whose runtime has gone - answers nothing here, and the question here still waits.
    func testAnAnswerUnderAnotherQueuesTicketAnswersNothing() throws {
        let gone = QuestionQueue<Int>()
        let theirs = gone.ask(1)
        let queue = QuestionQueue<String>()
        let ours = queue.ask("ours")

        XCTAssertNotEqual(ours.ticket, theirs.ticket)
        XCTAssertNil(queue.answered(theirs.ticket))
        XCTAssertEqual(try XCTUnwrap(queue.answered(ours.ticket)).question, "ours", "still waiting for its own")
    }

    /// An act is aimed at the element its first argument names; one naming none, or one not on screen, fails with
    /// the reason.
    func testAnActIsAimedAtTheElementItNames() {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([HostPatch(id: .manual("field"), type: .textField)])
        runtime.tree.apply(root, complete: true)

        XCTAssertEqual(try? runtime.tree.aimed(HostActCall(act: .focus, arguments: [.string("field")], completion: 1)).id,
                       .manual("field"))
        XCTAssertThrowsError(try runtime.tree.aimed(HostActCall(act: .focus, arguments: [], completion: 1)))
        XCTAssertThrowsError(try runtime.tree.aimed(HostActCall(act: .focus, arguments: [.string("gone")], completion: 1)))
    }
}
