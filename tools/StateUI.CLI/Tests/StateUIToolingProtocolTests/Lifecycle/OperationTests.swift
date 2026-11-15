// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import XCTest

final class OperationTests: XCTestCase {
    private func work(_ token: String, _ fields: String = #""steps":2"#) -> String {
        #"{"requestToken":"\#(token)",\#(fields)}"#
    }

    private func events(_ messages: [JSONValue]) -> [JSONValue] {
        messages.filter { $0["method"] == .string("operation/event") }.compactMap { $0["params"] }
    }

    private func kinds(_ messages: [JSONValue]) -> [String] {
        events(messages).map { event in
            switch event["event"]?["kind"] {
            case .string("state")?:
                if case .string(let state)? = event["event"]?["state"] { return state }
                return "state"
            case .string(let kind)?: return kind
            default: return "?"
            }
        }
    }

    private func ended(_ messages: [JSONValue]) -> Bool {
        let last = kinds(messages).last
        return ["succeeded", "failed", "cancelled", "interrupted"].contains(last ?? "")
    }

    private func handle(_ message: JSONValue?) -> String? {
        if case .string(let id)? = message?["result"]?["operationId"] { id } else { nil }
    }

    /// A mutation answers with its queued handle first; its events follow, numbered from 1 in order, ending in
    /// its terminal state - and `operation/get` gives it whole.
    func testAMutationAnswersBeforeItsEventsWhichComeNumberedInOrder() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":2,"output":"żółw\n""#))
        let messages = try await client.messages(until: ended)

        XCTAssertEqual(messages.first?["result"]?["state"], .string("queued"))
        XCTAssertEqual(kinds(messages), ["running", "progress", "progress", "output", "succeeded"])
        XCTAssertEqual(events(messages).map { $0["sequence"] }, (1...5).map { .number(Double($0)) })
        let output = events(messages)[3]["event"]
        XCTAssertEqual(output?["data"], .string("żółw\n"))
        XCTAssertEqual(output?["encoding"], .string("utf8"))
        XCTAssertEqual(output?["cursor"], .string("stdout:8"))

        let id = try XCTUnwrap(handle(messages.first))
        await client.request("2", "operation/get", #"{"operationId":"\#(id)"}"#)
        let snapshot = try await client.messages().first?["result"]
        XCTAssertEqual(snapshot?["state"], .string("succeeded"))
        XCTAssertEqual(snapshot?["result"], .object(["steps": .number(2)]))
        XCTAssertEqual(snapshot?["lastSequence"], .number(5))
        XCTAssertEqual(snapshot?["kind"], .string("test/work"))
    }

    /// The same token with the same request is the same operation, run once; with another request it is refused.
    func testATokenStandsForOneRequestRunOnce() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1"))
        let first = try await client.messages(until: ended)
        await client.request("2", "test/work", work("t1"))
        await client.request("3", "test/work", work("t1", #""steps":3"#))
        let again = try await client.messages()

        XCTAssertEqual(again.count, 2)
        XCTAssertEqual(handle(again[0]), handle(first[0]))
        XCTAssertEqual(again[0]["result"]?["state"], .string("succeeded"))
        XCTAssertEqual(again[1]["error"]?["data"]?["code"], .string("REQUEST_TOKEN_CONFLICT"))
    }

    /// A mutation takes a token, and its parameters are read whole beside it.
    func testAMutationTakesATokenAndItsOwnFields() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", #"{"steps":1}"#)
        await client.request("2", "test/work", work("t1", #""steps":1,"extra":true"#))
        let messages = try await client.messages()

        XCTAssertEqual(messages.map { $0["error"]?["code"] }, [.number(-32602), .number(-32602)])
        XCTAssertEqual(messages[1]["error"]?["message"], .string("test/work takes no /extra."))
    }

    /// A running operation asked to stop goes through cancelling to cancelled; asking again changes nothing.
    func testCancellingARunningOperation() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":1,"holds":true"#))
        let started = try await client.messages(until: { self.kinds($0).last == "progress" })
        let id = try XCTUnwrap(handle(started.first))
        await client.request("2", "operation/cancel", #"{"operationId":"\#(id)"}"#)
        let cancelled = try await client.messages(until: ended)
        await client.request("3", "operation/cancel", #"{"operationId":"\#(id)"}"#)
        let again = try await client.messages()

        let answer = cancelled.first { $0["id"] == .string("2") }
        XCTAssertEqual(answer?["result"], .object(["accepted": .bool(true), "state": .string("cancelling")]))
        XCTAssertEqual(kinds(cancelled), ["cancelling", "cancelled"])
        XCTAssertEqual(again.first?["result"], .object(["accepted": .bool(true), "state": .string("cancelled")]))
    }

    /// A cancel coming after the operation succeeded is not accepted, and the success stands.
    func testACancelAfterSuccessIsNotAccepted() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1"))
        let done = try await client.messages(until: ended)
        let id = try XCTUnwrap(handle(done.first))
        await client.request("2", "operation/cancel", #"{"operationId":"\#(id)"}"#)
        let messages = try await client.messages()
        XCTAssertEqual(messages.first?["result"], .object(["accepted": .bool(false), "state": .string("succeeded")]))
    }

    /// A failed operation keeps the error it failed with; an operation not there is not found.
    func testAFailedOperationKeepsItsError() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":1,"fails":true"#))
        let done = try await client.messages(until: ended)
        let id = try XCTUnwrap(handle(done.first))
        await client.request("2", "operation/get", #"{"operationId":"\#(id)"}"#)
        await client.request("3", "operation/get", #"{"operationId":"op-none"}"#)
        let messages = try await client.messages()
        let answer = { (id: String) in messages.first { $0["id"] == .string(id) } }

        XCTAssertEqual(answer("2")?["result"]?["state"], .string("failed"))
        XCTAssertEqual(answer("2")?["result"]?["failure"]?["code"], .string("NOT_FOUND"))
        XCTAssertEqual(answer("3")?["error"]?["data"]?["code"], .string("NOT_FOUND"))
    }

    /// A batch's answers are written before any event of the operations it started.
    func testABatchIsAnsweredBeforeItsOperationsEvents() async throws {
        let client = Client()
        try await client.open()
        await client.send(
            #"[{"jsonrpc":"2.0","id":"a","method":"test/work","params":\#(work("ta"))},"#
                + #"{"jsonrpc":"2.0","id":"b","method":"test/work","params":\#(work("tb"))}]"#)
        let messages = try await client.messages(until: { self.kinds($0).filter { $0 == "succeeded" }.count == 2 })

        guard case .array(let answers)? = messages.first else { return XCTFail("\(messages.first as Any)") }
        XCTAssertEqual(answers.map { $0["result"]?["state"] }, [.string("queued"), .string("queued")])
        XCTAssertEqual(events(messages).count, 8)
    }

    /// Output a congested client is not sent becomes a gap, said before the operation's end - never a whole log.
    func testOutputACongestedClientMissesIsAGapBeforeTheEnd() async throws {
        let client = Client()
        try await client.open()
        client.leaveUnread(EventChannel.backlogLimit + 1)
        await client.request("1", "test/work", work("t1", #""steps":1,"output":"lost","errorBytes":70000"#))
        let messages = try await client.messages(until: ended)

        XCTAssertEqual(kinds(messages), ["running", "progress", "outputGap", "outputGap", "succeeded"])
        let gaps = events(messages).compactMap { $0["event"] }.filter { $0["kind"] == .string("outputGap") }
        XCTAssertEqual(gaps.map { $0["fromCursor"] }, [.string("stdout:0"), .string("stderr:0")])
        XCTAssertEqual(gaps.map { $0["toCursor"] }, [.string("stdout:4"), .string("stderr:70000")])
        XCTAssertEqual(gaps.map { $0["replayAvailable"] }, [.bool(false), .bool(false)])
    }

    /// `shutdown` stops the client's operations, and is answered once they ended.
    func testShutdownStopsTheClientsOperationsFirst() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":1,"holds":true"#))
        _ = try await client.messages(until: { self.kinds($0).last == "progress" })
        await client.request("down", "shutdown")
        let messages = try await client.messages()

        XCTAssertEqual(kinds(messages), ["cancelling", "cancelled"])
        XCTAssertEqual(messages.last?["id"], .string("down"))
    }

    /// The connection's end stops the client's operations before it returns.
    func testTheEndStopsTheClientsOperations() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":1,"holds":true"#))
        let started = try await client.messages(until: { self.kinds($0).last == "progress" })
        await client.connection.end()
        let id = try XCTUnwrap(handle(started.first))
        let snapshot = try await client.methods.operations.snapshot(id)
        XCTAssertEqual(snapshot.state, .cancelled)
    }

    /// A client leaving more than the backlog's limit unread past its time is lost: the connection ends and its
    /// operations stop.
    func testAClientThatStopsReadingIsLost() async throws {
        let client = Client(lostAfter: .milliseconds(200))
        try await client.open()
        await client.request("1", "test/work", work("t1", #""steps":1,"holds":true"#))
        _ = try await client.messages(until: { self.kinds($0).last == "progress" })
        client.leaveUnread(EventChannel.backlogLimit + 1)
        let lost = Task { await client.connection.closed() }
        let deadline = Task { try await Task.sleep(for: .seconds(5)); lost.cancel() }
        await lost.value
        deadline.cancel()

        let state = await client.connection.state
        XCTAssertEqual(state, .closed)
        XCTAssertTrue(client.diagnosed.contains { $0.contains("lost") })
    }

    /// A request of a lost client is called off - no answer reaches a client that reads nothing - and the
    /// connection's end waits for none.
    func testARequestOfALostClientIsCalledOff() async throws {
        let client = Client(lostAfter: .milliseconds(200))
        try await client.open()
        await client.request("1", "test/waits", #"{"text":"x"}"#)
        let service = client.service
        try await wait { service.waits.withLock { $0.began } }
        client.leaveUnread(EventChannel.backlogLimit + 1)
        try await wait { service.waits.withLock { $0.calledOff } }
        let calledOff = service.waits.withLock { $0.calledOff }
        XCTAssertTrue(calledOff, "the request went on for a client that reads nothing")
        guard calledOff else { return }

        let began = ContinuousClock.now
        await client.connection.end()
        XCTAssertLessThan(ContinuousClock.now - began, .seconds(2))
        let lost = await client.connection.lost
        XCTAssertTrue(lost)
    }

    /// A request that hears no call keeps no lost client's connection: its end goes on without the request once a
    /// stop's limit has passed.
    func testALostClientsConnectionEndsWithoutARequestThatHearsNoCall() async throws {
        let client = Client(lostAfter: .milliseconds(200), stopLimit: .milliseconds(300))
        try await client.open()
        await client.request("1", "test/slow", #"{"text":"x"}"#)
        client.leaveUnread(EventChannel.backlogLimit + 1)
        let ended = Flag()
        let ending = Task {
            await client.connection.closed()
            await client.connection.end()
            ended.raise()
        }
        try await wait { ended.isRaised }
        XCTAssertTrue(ended.isRaised, "the connection waited for a request that hears no call")

        await client.service.gate.release()
        await ending.value
    }

    /// Waits, up to five seconds, until `done` holds.
    private func wait(until done: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !done(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    }

    /// A stream's bytes come in chunks below 64 KiB cut where a character ends; bytes not UTF-8 come as Base64.
    func testOutputComesInChunksCutAtCharacters() {
        let text = Array(String(repeating: "ż", count: 40000).utf8)
        let chunks = OutputChunker.chunks(of: text)
        XCTAssertEqual(chunks.map(\.count), [65534, 14466])
        XCTAssertEqual(chunks.map(\.encoding), [.utf8, .utf8])
        XCTAssertEqual(chunks.map(\.data).joined(), String(repeating: "ż", count: 40000))

        let binary = OutputChunker.chunks(of: [0xFF, 0x00, 0x41])
        XCTAssertEqual(binary.map(\.encoding), [.base64])
        XCTAssertEqual(binary.map(\.data), ["/wBB"])
    }
}

/// Something that happened, said from any task.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false

    func raise() { lock.withLock { raised = true } }

    var isRaised: Bool { lock.withLock { raised } }
}
