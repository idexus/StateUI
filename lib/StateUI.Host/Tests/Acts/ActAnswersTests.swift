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
        let confirm = try XCTUnwrap(HostQuestion(HostActCall(act: .confirm, arguments: [.string("Delete?")], completion: 1)))
        XCTAssertEqual(confirm.title, "Delete?")
        XCTAssertEqual(confirm.accept, "OK")
        XCTAssertEqual(confirm.cancel, "Cancel")

        let choose = try XCTUnwrap(HostQuestion(HostActCall(
            act: .chooseAction, arguments: [.string("Share"), .nothing, .string("Delete"), ["Mail", "Copy"].propValue],
            completion: 2)))
        XCTAssertNil(choose.cancel, "a choice offers a cancel only where it names one")
        XCTAssertEqual(choose.destruction, "Delete")
        XCTAssertEqual(choose.choices, ["Mail", "Copy"])

        let prompt = try XCTUnwrap(HostQuestion(HostActCall(
            act: .prompt, arguments: [.string("Name"), .nothing, .nothing, .nothing, .string("Ada"), .number(8),
                                      InputPurpose.email.propValue, .string("ada@")], completion: 3)))
        XCTAssertEqual(prompt.placeholder, "Ada")
        XCTAssertEqual(prompt.maximumLength, 8)
        XCTAssertEqual(prompt.purpose, .email)
        XCTAssertEqual(prompt.words, "ada@")
        XCTAssertNil(HostQuestion(HostActCall(act: .announce, arguments: [], completion: nil)))
    }

    /// A confirmation answers yes or no; a choice or a prompt its words where the user accepted, nothing where
    /// not; an alert nothing.
    func testAQuestionAnswersAsItsKindDoes() throws {
        func question(_ act: Act) throws -> HostQuestion { try XCTUnwrap(HostQuestion(HostActCall(act: act, arguments: [], completion: 1))) }
        XCTAssertEqual(try question(.confirm).answer(accepted: true, words: nil), [.bool(true)])
        XCTAssertEqual(try question(.prompt).answer(accepted: true, words: "Ada"), ["Ada".propValue])
        XCTAssertEqual(try question(.prompt).answer(accepted: false, words: "Ada"), [(nil as String?).propValue])
        XCTAssertEqual(try question(.alert).answer(accepted: true, words: nil), [])
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
