// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What Swift asks the host to do, and how the answer gets back.
//
// These stand in for the host by hand: start the act, read what was queued,
// report an outcome under the completion id, and see what the awaiting side
// makes of it. That is the whole protocol, and it is the same one whether the
// caller is `try await Dialogs.alert(…)` or an application's own act.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

final class ActCallTests: XCTestCase {
    // MARK: - The name

    /// An act is never called a command. The queue, its take and its receipt,
    /// the C exports, the typed SPI, the hosts and the handbook spell act
    /// calls; a drawing's commands are another thing and keep their word.
    func testTheActPathSpellsNoCommand() throws {
        let removed = [
            "HostCommand", "SwiftCommand", "takeCommands", "TakeCommands",
            "failTakenCommands", "FailTakenCommands", "commandsPending",
            "PerformCommands", "ReadCommands", "stateui_take_commands_wire",
            "stateui_fail_taken_commands", "unknown command", "Command.swift",
            "fixtures/commands", "\"commands/",
        ]

        var files = try Fixtures.allSources().map {
            (path: "lib/StateUI/Sources/\($0.path)", text: $0.text)
        }
        for tree in ["lib/StateUI.AppKit/Sources", "lib/StateUI.Android/Sources", "docs"] {
            files += try Self.files(under: tree)
        }
        files.append((
            path: "README.md",
            text: try String(
                contentsOf: Fixtures.repository.appendingPathComponent("README.md"),
                encoding: .utf8)))

        let found = files.flatMap { file in
            removed.filter(file.text.contains).map { "\(file.path): \($0)" }
        }
        XCTAssertEqual(found, [], "an act on its way to the host is an act call, never a command")
    }

    /// The Swift and Markdown files of one tree, build output left out.
    private static func files(under tree: String) throws -> [(path: String, text: String)] {
        let root = Fixtures.repository.appendingPathComponent(tree)
        var found: [(path: String, text: String)] = []
        for path in try Fixtures.files(under: root, entering: Fixtures.entersSources)
        where [".swift", ".md"].contains(where: path.hasSuffix) {
            found.append((
                path: "\(tree)/\(path)",
                text: try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)))
        }
        return found.sorted { $0.path < $1.path }
    }

    /// The queue is on the shared renderer, so a test starts by emptying it.
    @discardableResult
    private func drain() -> [HostActCall] {
        drainedActs()
    }

    /// What a handler's body is, when it gives an answer back.
    ///
    /// Spelled as an alias because `nonisolated(nonsending)` cannot be written
    /// inline in a parameter type - the same reason EventHandler exists.
    private typealias Act<Value> = nonisolated(nonsending) () async throws -> Value

    /// Starts an act and lets it reach its suspension, the way an event does.
    ///
    /// On MainActor, where `Task.immediate` runs the body inline up to its
    /// first suspension - what `Renderer.dispatch` does for a real event - so by
    /// the time this returns the act is on the act queue. Deterministic, not a
    /// race.
    @MainActor
    private static func begin<Value>(_ body: sending @escaping Act<Value>) -> Task<Value, Error> {
        Task.immediate { @MainActor in try await body() }
    }

    /// The completion id in a taken batch, which is what the host quotes back.
    private func completionId(in acts: [HostActCall]) throws -> Int {
        let id = try XCTUnwrap(
            acts.compactMap(\.completion).first,
            "no completion id in \(PatchDump.text(acts))")

        XCTAssertLessThan(id, 0,
                          "negative, so it can never be mistaken for an element's handler id")

        return id
    }

    /// What the host does when it has finished an act: report the outcome, then
    /// run the work the resume produces.
    @discardableResult
    private func report(_ id: Int, _ reply: Reply) async -> Bool {
        ReplyBuffer.current = reply
        let known = Renderer.shared.dispatch(id)
        if known { await settle() }
        return known
    }

    // MARK: - What goes out

    func testAnAlertQueuesItsActByName() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }

        let acts = drain()
        XCTAssertEqual(acts.first?.name, "alert")
        XCTAssertEqual(acts.first?.arguments.first, .string("//list"))

        await report(try completionId(in: acts), .finished([]))
        try await navigation.value
    }

    /// SAYING SOMETHING OUT LOUD IS AN ACT, and it aims at no control: a
    /// screen reader speaks for the application, not for one view - which is
    /// why the words are argument 0 where an aimed act keeps a view name
    /// there.
    func testAnnouncingQueuesTheWordsWithNoTarget() async throws {
        drain()

        let said = await Self.begin { try await ScreenReader.announce("Row deleted") }

        let acts = drain()
        XCTAssertEqual(acts.first?.name, "announce")
        XCTAssertEqual(acts.first?.arguments, [.string("Row deleted")])

        await report(try completionId(in: acts), .finished([]))
        try await said.value
    }

    func testTakingTheActCallsEmptiesTheQueue() async throws {
        drain()
        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }

        let acts = drain()
        XCTAssertFalse(acts.isEmpty)
        XCTAssertTrue(drain().isEmpty, "an act is handed over once")

        await report(try completionId(in: acts), .finished([]))
        try await navigation.value
    }

    /// An act sent rather than called has nobody waiting for it, so it
    /// carries no completion: there is no caller to quote back to.
    func testAnActNobodyIsWaitingForCarriesNoCompletion() {
        drain()

        stateUISend(TestActs.copy, "note")

        let acts = drain()
        XCTAssertEqual(acts.first?.name, "Test.Copy")
        XCTAssertNil(acts.first?.completion,
                     "nothing is waiting, so there is no id to quote back")
    }

    /// A number is eight bytes of a double, so a NaN and an infinity cross as
    /// themselves and nothing is substituted for them anywhere: the batch stays
    /// readable, and every argument after one is still at its own place.
    ///
    /// The refusal happens in the host instead, which is where it belongs -
    /// the HOST's typed accessors answer "not a number" for a non-finite, so a
    /// value nobody could act on is refused by whoever would have acted on it.
    /// That half is each host's to pin.
    func testANumberThatIsNotFiniteCrossesAsItsOwnBits() throws {
        drain()

        stateUISend(TestActs.numbers, Double.nan, Double.infinity, -Double.infinity, 1)

        let acts = drain()
        let arguments = try XCTUnwrap(acts.first?.arguments)
        XCTAssertEqual(arguments.count, 4, "the batch stays readable, values and all")

        guard case .number(let first) = arguments[0] else { return XCTFail("\(arguments[0])") }
        XCTAssertTrue(first.isNaN)
        XCTAssertEqual(arguments[1], .number(.infinity))
        XCTAssertEqual(arguments[2], .number(-.infinity))
        XCTAssertEqual(arguments[3], .number(1))
    }

    /// A handler that awaits twice suspends twice, and the second act reaches
    /// the queue only when the first has been reported - which is how the host
    /// sees them, one at a time, in order.
    func testASecondAwaitQueuesOnlyAfterTheFirstIsReported() async throws {
        drain()

        let navigation = await Self.begin {
            try await Dialogs.alert("//first", message: "saved")
            try await Dialogs.alert("//second", message: "saved")
        }

        let first = drain()
        XCTAssertEqual(first.count, 1, "the handler is still suspended on the first")
        XCTAssertEqual(first.first?.arguments.first, .string("//first"))

        await report(try completionId(in: first), .finished([]))

        let second = drain()
        XCTAssertEqual(second.first?.arguments.first, .string("//second"))

        await report(try completionId(in: second), .finished([]))
        try await navigation.value
    }

    // MARK: - What comes back

    func testTheResultOfAnActReachesTheCaller() async throws {
        drain()

        let asked = await Self.begin { try await stateUICall(TestActs.choose, "Delete?") }

        await report(try completionId(in: drain()), .finished([.string("Delete")]))

        let answer = try await asked.value
        XCTAssertEqual(answer, "Delete")
    }

    /// A dialog's answer can be NOTHING - a cancelled prompt, a sheet
    /// dismissed without choosing - and can also be EMPTY, which is an answer:
    /// a prompt accepted with nothing typed. The reply's COUNT is what keeps
    /// the two apart: a choice is one string value, empty included, and a
    /// dismissal is no values at all.
    func testADialogAnswerTellsNothingFromEmpty() async throws {
        drain()

        let sheet = await Self.begin {
            try await Dialogs.chooseAction("Share via", buttons: ["Mail"])
        }
        await report(try completionId(in: drain()), .finished([.string("Mail")]))
        let choice = try await sheet.value
        XCTAssertEqual(choice, "Mail")

        let accepted = await Self.begin { try await Dialogs.prompt("Rename") }
        await report(try completionId(in: drain()), .finished([.string("")]))
        let typed = try await accepted.value
        XCTAssertEqual(typed, "", "accepted with nothing typed is an empty answer")

        let cancelled = await Self.begin { try await Dialogs.prompt("Rename") }
        await report(try completionId(in: drain()), .finished([]))
        let nothing = try await cancelled.value
        XCTAssertNil(nothing, "cancelled is no answer at all")
    }

    /// The question form reads the host's bool, the way focus() does.
    func testAQuestionAlertAnswersWhatWasPressed() async throws {
        drain()

        let asked = await Self.begin {
            try await Dialogs.confirm(
                "Delete?", message: "Sure?", accept: "Delete", cancel: "Keep")
        }
        await report(try completionId(in: drain()), .finished([.bool(true)]))
        let accepted = try await asked.value
        XCTAssertTrue(accepted)
    }

    func testAFailureReportedByTheHostIsThrown() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//nowhere", message: "saved") }

        await report(try completionId(in: drain()), .failed("there is no page to show a dialog on"))

        do {
            try await navigation.value
            XCTFail("a failed act should throw")
        } catch let error as StateUIError {
            XCTAssertEqual(error.message, "there is no page to show a dialog on")
        }
    }

    /// An empty result and an empty complaint are different answers, which is
    /// the whole reason the reply carries a tag: an act that answers nothing
    /// finishes, and its caller carries on.
    func testAnEmptyResultIsNotAFailure() async throws {
        drain()

        let asked = await Self.begin { try await stateUICall(TestActs.nothing) }
        await report(try completionId(in: drain()), .finished([]))

        try await asked.value
    }

    /// A reply whose bytes will not read - version skew - must still resume
    /// the waiting handler: the dispatch entry turns it into a failure, never
    /// a hang. Driven through the real export, bytes and all.
    func testAnUnreadableReplyFailsTheActInsteadOfHangingIt() async throws {
        drain()

        let asked = await Self.begin { try await stateUICall(TestActs.old) }
        let id = try completionId(in: drain())

        let garbage: [UInt8] = [99, 1, 2, 3]
        garbage.withUnsafeBufferPointer { bytes in
            _ = stateui_dispatch_wire(Int32(id), bytes.baseAddress, Int32(bytes.count))
        }
        await settle()

        do {
            _ = try await asked.value
            XCTFail("an unreadable reply is a version mismatch, not a result")
        } catch let error as StateUIError {
            XCTAssertTrue(error.message.contains("could not be read"), error.message)
        }
    }

    // MARK: - What a resume owes

    /// A resume is owed from the moment its outcome is reported until the
    /// handler runs again - the job that continues it does not exist yet when
    /// the report returns, and lands a moment later.
    ///
    /// Read as a difference rather than an absolute: the renderer is shared, so
    /// what this test can honestly say is what its own act did to the count.
    func testAResumeIsOwedFromTheMomentItIsReportedUntilItLands() async throws {
        drain()
        let owed = Renderer.shared.resumesPending

        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }
        let id = try completionId(in: drain())

        XCTAssertEqual(Renderer.shared.resumesPending, owed,
                       "suspended is not owed: nothing has been reported yet")

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(id))

        XCTAssertEqual(Renderer.shared.resumesPending, owed + 1, """
            Reported, and the job that continues the handler does not exist yet - \
            `resume()` schedules rather than continues, measured.
            """)

        await settle()

        XCTAssertEqual(Renderer.shared.resumesPending, owed,
                       "the handler came back, so nothing is owed")

        try await navigation.value
    }

    /// A completion that resumed nobody owes nothing, so there is nothing to
    /// wait for and nothing to complain about - a resume owed with nobody to
    /// make it would keep the host asking on every turn.
    func testACompletionThatResumedNobodyOwesNothing() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }
        let id = try completionId(in: drain())

        await report(id, .finished([]))
        try await navigation.value

        let owed = Renderer.shared.resumesPending
        XCTAssertFalse(Renderer.shared.dispatch(id), "a completion runs once")
        XCTAssertEqual(Renderer.shared.resumesPending, owed)
    }

    func testAnActIsReportedOnce() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }
        let id = try completionId(in: drain())

        let ran = await report(id, .finished([]))
        XCTAssertTrue(ran)
        try await navigation.value

        let again = await report(id, .finished([]))
        XCTAssertFalse(again, "a completion runs once")
    }

    /// A batch the host could not read is failed back by RECEIPT: the take
    /// remembers the completion ids it handed out - they are inside the very
    /// bytes that would not read, so only this side still knows them - and
    /// cashing the receipt resumes every awaiting handler by THROWING the
    /// reason. The alternative was a continuation parked forever, with
    /// nothing anywhere saying why. Deliberately not a timeout: an act may
    /// wait unboundedly and legitimately - a dialog waits for the user.
    func testAnUnreadableBatchFailsItsActInsteadOfHangingIt() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//list", message: "saved") }
        XCTAssertFalse(drain().isEmpty)

        Renderer.shared.failTakenActCalls("the host could not read the batch")
        await settle()

        do {
            try await navigation.value
            XCTFail("an act in an unreadable batch reported success")
        } catch {
            XCTAssertTrue(
                String(describing: error).contains("could not read the batch"),
                String(describing: error))
        }
    }

    /// The receipt is cashed ONCE - taken and cleared before anything runs -
    /// so a stale second cashing fails nobody: an act queued afterwards is
    /// untouched by it and completes normally.
    func testTheReceiptIsCashedOnce() async throws {
        drain()

        let first = await Self.begin { try await Dialogs.alert("//list", message: "saved") }
        XCTAssertFalse(drain().isEmpty)

        Renderer.shared.failTakenActCalls("unreadable")
        await settle()

        do {
            try await first.value
            XCTFail("the failed batch's act reported success")
        } catch {}

        // Queued but NOT yet taken, so no receipt covers it - the stale
        // cashing below must leave it alone.
        let second = await Self.begin { try await Dialogs.alert("//home", message: "saved") }
        Renderer.shared.failTakenActCalls("stale")

        let acts = drain()
        await report(try completionId(in: acts), .finished([]))
        try await second.value
    }

    // MARK: - A host in this process

    /// A native host in this process answers through the typed SPI: the
    /// caller resumes with the values exactly as they were handed over, and
    /// a call is answered once.
    func testATypedReplyReachesTheCaller() async throws {
        drain()

        let asked = await Self.begin { try await stateUICall(TestActs.choose, "Delete?") }
        let call = try XCTUnwrap(StateUIHost.takeActCalls().first)
        let id = try XCTUnwrap(call.completion)

        XCTAssertEqual(call.act, "Test.Choose")
        XCTAssertEqual(call.arguments, [.string("Delete?")])
        XCTAssertTrue(StateUIHost.reply(id, with: [.string("Delete")]))
        await settle()

        let answer = try await asked.value
        XCTAssertEqual(answer, "Delete")
        XCTAssertFalse(StateUIHost.reply(id, with: []), "a call is answered once")
    }

    /// A typed failure is what the caller throws: the host's reason, never a
    /// silence and never a hang.
    func testATypedFailureIsThrownWithTheHostsReason() async throws {
        drain()

        let navigation = await Self.begin { try await Dialogs.alert("//nowhere", message: "saved") }
        let id = try XCTUnwrap(StateUIHost.takeActCalls().first?.completion)

        XCTAssertTrue(StateUIHost.fail(id, reason: "there is no page to show a dialog on"))
        await settle()

        do {
            try await navigation.value
            XCTFail("a failed act should throw")
        } catch let error as StateUIError {
            XCTAssertEqual(error.message, "there is no page to show a dialog on")
        }
    }

    /// Only a completion id is answered: a positive number is an element's
    /// handler, never a caller.
    func testATypedAnswerToAnEventIdAnswersNobody() {
        XCTAssertFalse(StateUIHost.reply(7, with: []))
        XCTAssertFalse(StateUIHost.fail(7, reason: "not a completion"))
    }
}

/// Acts of an application's own, declared the way an application declares
/// them - what the tests of a call's round trip perform.
private enum TestActs: ApplicationTier {
    static let name = "Test"

    static let choose = ElementAct<Self, String, String>("Test.Choose")
    static let copy = ElementAct<Self, String, Void>("Test.Copy")
    static let numbers = ElementAct<Self, (Double, Double, Double, Double), Void>("Test.Numbers")
    static let nothing = ElementAct<Self, Void, Void>("Test.Nothing")
    static let old = ElementAct<Self, Void, Void>("Test.Old")

    static let members: [any ContractMember] = [choose, copy, numbers, nothing, old]
}
