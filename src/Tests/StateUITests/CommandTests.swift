// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What Swift asks the host to do, and how the answer gets back.
//
// These stand in for the host by hand: start the act, read what was queued,
// report an outcome under the completion id, and see what the awaiting side
// makes of it. That is the whole protocol, and it is the same one whether the
// caller is `try await Dialogs.displayAlert(…)` or a typed call added later.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class CommandTests: XCTestCase {
    /// The queue is on the shared renderer, so a test starts by emptying it -
    /// and reads what it took through the probe, values already apart.
    @discardableResult
    private func drain() -> [WireAct] {
        WireProbe.decode(Renderer.shared.takeCommandsWire())
    }

    /// What a handler's body is, when it gives an answer back.
    ///
    /// Spelled as an alias because `nonisolated(nonsending)` cannot be written
    /// inline in a parameter type - the same reason EventHandler exists.
    private typealias Act<Value> = nonisolated(nonsending) () async throws -> Value

    /// Starts an act and lets it reach its suspension, the way an event does.
    ///
    /// `Task` queues its first job on this thread synchronously, and running the
    /// queue here is what `Renderer.dispatch` does for a real event - so by the
    /// time this returns the act is on the command queue. Deterministic, not a
    /// race.
    private func begin<Value>(_ body: sending @escaping Act<Value>) -> Task<Value, Error> {
        let task = Task { @MainThread in try await body() }
        stateUIRunJobs()
        return task
    }

    /// The completion id in a taken batch, which is what the host quotes back.
    private func completionId(in acts: [WireAct]) throws -> Int {
        let id = try XCTUnwrap(
            acts.compactMap(\.completion).first,
            "no completion id in \(WireProbe.dump(acts))")

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

    func testNavigatingQueuesTheMauiMethodByName() async throws {
        drain()

        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }

        let acts = drain()
        XCTAssertEqual(acts.first?.name, "displayAlertAsync")
        XCTAssertEqual(acts.first?.arguments.first, .string("//list"))

        await report(try completionId(in: acts), .finished([]))
        try await navigation.value
    }

    func testTakingTheCommandsEmptiesTheQueue() async throws {
        drain()
        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }

        let acts = drain()
        XCTAssertFalse(acts.isEmpty)
        XCTAssertTrue(drain().isEmpty, "an act is handed over once")

        await report(try completionId(in: acts), .finished([]))
        try await navigation.value
    }

    /// Also the by-name ESCAPE: the ledger has no id for a method the library
    /// does not wrap, so the name itself crosses - id 0, then the string.
    func testAnActNobodyIsWaitingForCarriesNoCompletion() {
        drain()

        stateUISend("Clipboard.SetTextAsync", [.string("note")])

        let acts = drain()
        XCTAssertEqual(acts.first?.name, "Clipboard.SetTextAsync")
        XCTAssertNil(acts.first?.completion,
                     "nothing is waiting, so there is no id to quote back")
    }

    /// A number is eight bytes of a double, so a NaN and an infinity cross as
    /// themselves and nothing is substituted for them anywhere: the batch stays
    /// readable, and every argument after one is still at its own place.
    ///
    /// The refusal happens at the far end instead, which is where it belongs -
    /// the HOST's typed accessors answer "not a number" for a non-finite, so a
    /// value nobody could act on is refused by whoever would have acted on it.
    /// That half is pinned on the C# side.
    func testANumberThatIsNotFiniteCrossesAsItsOwnBits() throws {
        drain()

        stateUISend("Something.Numeric", [
            .number(Double.nan),
            .number(.infinity),
            .number(-.infinity),
            .number(1),
        ])

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

        let navigation = begin {
            try await Dialogs.displayAlert("//first", message: "saved")
            try await Dialogs.displayAlert("//second", message: "saved")
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

        let asked = begin {
            try await stateUICall("Page.DisplayActionSheet", [.string("Delete?")])
        }

        await report(try completionId(in: drain()), .finished([.string("Delete")]))

        let answer = try await asked.value
        XCTAssertEqual(answer, [.string("Delete")])
    }

    /// A dialog's answer can be NOTHING - a cancelled prompt, a sheet
    /// dismissed without choosing - and can also be EMPTY, which is an answer:
    /// a prompt accepted with nothing typed. The reply's COUNT is what keeps
    /// the two apart: a choice is one string value, empty included, and a
    /// dismissal is no values at all.
    func testADialogAnswerTellsNothingFromEmpty() async throws {
        drain()

        let sheet = begin {
            try await Dialogs.displayActionSheet("Share via", buttons: ["Mail"])
        }
        await report(try completionId(in: drain()), .finished([.string("Mail")]))
        let choice = try await sheet.value
        XCTAssertEqual(choice, "Mail")

        let accepted = begin { try await Dialogs.displayPrompt("Rename") }
        await report(try completionId(in: drain()), .finished([.string("")]))
        let typed = try await accepted.value
        XCTAssertEqual(typed, "", "accepted with nothing typed is an empty answer")

        let cancelled = begin { try await Dialogs.displayPrompt("Rename") }
        await report(try completionId(in: drain()), .finished([]))
        let nothing = try await cancelled.value
        XCTAssertNil(nothing, "cancelled is no answer at all")
    }

    /// The question form reads the host's bool, the way focus() does.
    func testAQuestionAlertAnswersWhatWasPressed() async throws {
        drain()

        let asked = begin {
            try await Dialogs.displayAlert(
                "Delete?", message: "Sure?", accept: "Delete", cancel: "Keep")
        }
        await report(try completionId(in: drain()), .finished([.bool(true)]))
        let accepted = try await asked.value
        XCTAssertTrue(accepted)
    }

    func testAFailureReportedByTheHostIsThrown() async throws {
        drain()

        let navigation = begin { try await Dialogs.displayAlert("//nowhere", message: "saved") }

        await report(try completionId(in: drain()), .failed("there is no page to show a dialog on"))

        do {
            try await navigation.value
            XCTFail("a failed act should throw")
        } catch let error as StateUIError {
            XCTAssertEqual(error.message, "there is no page to show a dialog on")
        }
    }

    /// An empty result and an empty complaint are different answers, which is
    /// the whole reason the reply carries a tag.
    func testAnEmptyResultIsNotAFailure() async throws {
        drain()

        let asked = begin { try await stateUICall("Something.Void") }
        await report(try completionId(in: drain()), .finished([]))

        let answer = try await asked.value
        XCTAssertEqual(answer, [])
    }

    /// A reply whose bytes will not read - version skew - must still resume
    /// the waiting handler: the dispatch entry turns it into a failure, never
    /// a hang. Driven through the real export, bytes and all.
    func testAnUnreadableReplyFailsTheActInsteadOfHangingIt() async throws {
        drain()

        let asked = begin { try await stateUICall("Something.Old") }
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

    // MARK: - What the host asks again on

    /// The host reports an outcome and then has to decide whether to keep
    /// looking for the work that continues the handler. This is what it decides
    /// on - see `StateUISession.DrainWhenTheResumeArrives`.
    ///
    /// Read as a difference rather than an absolute: the renderer is shared, so
    /// what this test can honestly say is what its own act did to the count.
    func testAResumeIsOwedFromTheMomentItIsReportedUntilItLands() async throws {
        drain()
        let owed = Renderer.shared.resumesPending

        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }
        let id = try completionId(in: drain())

        XCTAssertEqual(Renderer.shared.resumesPending, owed,
                       "suspended is not owed: nothing has been reported yet")

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(id))

        XCTAssertEqual(Renderer.shared.resumesPending, owed + 1, """
            Reported, and the job that continues the handler does not exist yet - \
            `resume()` schedules rather than continues, measured. This is the \
            window the host asks again in, and this is how it knows to.
            """)
        XCTAssertEqual(Int(stateui_resumes_pending()), owed + 1,
                       "and that is what the export hands over")

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

        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }
        let id = try completionId(in: drain())

        await report(id, .finished([]))
        try await navigation.value

        let owed = Renderer.shared.resumesPending
        XCTAssertFalse(Renderer.shared.dispatch(id), "a completion runs once")
        XCTAssertEqual(Renderer.shared.resumesPending, owed)
    }

    func testAnActIsReportedOnce() async throws {
        drain()

        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }
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
    /// wait unboundedly and legitimately - a dialog waits for the reader.
    func testAnUnreadableBatchFailsItsActInsteadOfHangingIt() async throws {
        drain()

        let navigation = begin { try await Dialogs.displayAlert("//list", message: "saved") }
        XCTAssertFalse(drain().isEmpty)

        Renderer.shared.failTakenCommands("the host could not read the batch")
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

        let first = begin { try await Dialogs.displayAlert("//list", message: "saved") }
        XCTAssertFalse(drain().isEmpty)

        Renderer.shared.failTakenCommands("unreadable")
        await settle()

        do {
            try await first.value
            XCTFail("the failed batch's act reported success")
        } catch {}

        // Queued but NOT yet taken, so no receipt covers it - the stale
        // cashing below must leave it alone.
        let second = begin { try await Dialogs.displayAlert("//home", message: "saved") }
        Renderer.shared.failTakenCommands("stale")

        let acts = drain()
        await report(try completionId(in: acts), .finished([]))
        try await second.value
    }
}
