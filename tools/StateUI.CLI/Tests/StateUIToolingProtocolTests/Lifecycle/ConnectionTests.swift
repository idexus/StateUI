// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import XCTest

final class ConnectionTests: XCTestCase {
    private func error(_ message: JSONValue?) -> Double? {
        if case .number(let code)? = message?["error"]?["code"] { code } else { nil }
    }

    /// A new connection answers `initialize` alone, and the service's methods once `initialized` came.
    func testAConnectionAnswersItsMethodsOnceInitialized() async throws {
        let client = Client()
        await client.request("1", "test/echo", #"{"text":"a"}"#)
        await client.request("2", "initialize", Client.initialize)
        await client.request("3", "test/echo", #"{"text":"b"}"#)
        await client.notify("initialized")
        await client.request("4", "test/echo", #"{"text":"c"}"#)
        let messages = try await client.messages()

        XCTAssertEqual(messages.count, 4)
        XCTAssertEqual(error(messages[0]), -32002)
        XCTAssertEqual(messages[1]["result"]?["apiVersion"], .string("1.0"))
        XCTAssertEqual(
            messages[1]["result"]?["capabilities"]?["methods"],
            .array(
                ["operation/cancel", "operation/get", "test/count", "test/echo", "test/fail", "test/refuse", "test/slow",
                 "test/work"].map(JSONValue.string)))
        XCTAssertEqual(messages[1]["result"]?["capabilities"]?["notifications"], .array([.string("operation/event")]))
        XCTAssertEqual(messages[1]["result"]?["workspace"], .object(["uri": .string("file:///w")]))
        XCTAssertEqual(error(messages[2]), -32002)
        XCTAssertEqual(messages[3]["result"], .object(["text": .string("c")]))
        let state = await client.connection.state
        XCTAssertEqual(state, .ready)
    }

    /// A client sharing no API version with the service is refused, and nothing it asks runs; it may try again.
    func testAClientSharingNoVersionIsRefusedBeforeAnythingRuns() async throws {
        let client = Client()
        let newer = Client.initialize.replacingOccurrences(of: #""major":1"#, with: #""major":2"#)
        await client.request("1", "initialize", newer)
        await client.notify("initialized")
        await client.request("2", "test/count")
        await client.request("3", "initialize", Client.initialize)
        let messages = try await client.messages()

        XCTAssertEqual(error(messages[0]), -32001)
        XCTAssertEqual(error(messages[1]), -32002)
        XCTAssertEqual(client.service.counted.withLock { $0 }, 0)
        XCTAssertEqual(messages[2]["result"]?["apiVersion"], .string("1.0"))
    }

    /// The newest version both speak is the connection's.
    func testTheNewestSharedVersionIsSpoken() {
        let client = [APIVersionRange(major: 1, minMinor: 1, maxMinor: 4), APIVersionRange(major: 2, minMinor: 0, maxMinor: 0)]
        XCTAssertEqual(APIVersionRange.newestShared(client, [APIVersionRange(major: 1, minMinor: 0, maxMinor: 2)]), "1.2")
        XCTAssertEqual(APIVersionRange.newestShared(client, [APIVersionRange(major: 1, minMinor: 0, maxMinor: 0)]), nil)
        XCTAssertEqual(
            APIVersionRange.newestShared(client, [.init(major: 1, minMinor: 0, maxMinor: 9), .init(major: 2, minMinor: 0, maxMinor: 3)]),
            "2.0")
    }

    /// `initialize` a second time is refused.
    func testInitializingTwiceIsRefused() async throws {
        let client = Client()
        try await client.open()
        await client.request("again", "initialize", Client.initialize)
        let messages = try await client.messages()
        XCTAssertEqual(error(messages.first), -32600)
    }

    /// Parameters are read whole: a field the method does not take is refused by its place; none sent is `{}`.
    func testParametersAreReadWhole() async throws {
        let client = Client()
        await client.request("1", "initialize", Client.initialize.replacingOccurrences(of: #""file:///w""#, with: #""file:///w","x":1"#))
        let refused = try await client.messages()
        try await client.open()
        await client.request("2", "test/echo", #"{"text":"a","extra":{"deep":1}}"#)
        await client.request("3", "test/echo", #"["a"]"#)
        await client.send(#"{"jsonrpc":"2.0","id":"4","method":"test/count"}"#)
        let messages = try await client.messages()
        let answer = { (id: String) in messages.first { $0["id"] == .string(id) } }

        XCTAssertEqual(error(refused.first), -32602)
        XCTAssertEqual(refused.first?["error"]?["message"], .string("initialize takes no /x."))
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(error(answer("2")), -32602)
        XCTAssertEqual(answer("2")?["error"]?["message"], .string("test/echo takes no /extra."))
        XCTAssertEqual(error(answer("3")), -32602)
        XCTAssertEqual(answer("4")?["result"], .object([:]))
    }

    /// A method's refusal carries its tooling error; any other failure is the service's. Answers are matched
    /// by id: one a method gives comes when its method returns.
    func testARefusalCarriesItsToolingError() async throws {
        let client = Client()
        try await client.open()
        await client.request("1", "test/refuse")
        await client.request("2", "test/fail")
        await client.request("3", "no/such")
        let messages = try await client.messages()
        let answer = { (id: String) in messages.first { $0["id"] == .string(id) } }

        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(error(answer("1")), -32010)
        XCTAssertEqual(answer("1")?["error"]?["data"]?["code"], .string("NOT_FOUND"))
        XCTAssertEqual(error(answer("2")), -32603)
        XCTAssertEqual(error(answer("3")), -32601)
    }

    /// A method sent as a notification does not run and is not answered; an unknown notification is passed over.
    func testAMethodSentAsANotificationDoesNotRun() async throws {
        let client = Client()
        try await client.open()
        await client.notify("test/count")
        await client.notify("no/such")
        let messages = try await client.messages()
        XCTAssertEqual(messages, [])
        XCTAssertEqual(client.service.counted.withLock { $0 }, 0)
        XCTAssertEqual(client.diagnosed.count, 1)
    }

    /// A batch is answered in one array, in its order, leaving its notifications out; a batch of notifications is not.
    func testABatchIsAnsweredTogetherInItsOrder() async throws {
        let client = Client()
        try await client.open()
        await client.send(
            #"[{"jsonrpc":"2.0","id":"a","method":"test/slow","params":{"text":"a"}},"#
                + #"{"jsonrpc":"2.0","method":"test/count"},5,"#
                + #"{"jsonrpc":"2.0","id":"b","method":"test/echo","params":{"text":"b"}}]"#)
        await client.send(#"[{"jsonrpc":"2.0","method":"initialized"}]"#)
        await client.service.gate.release()
        let messages = try await client.messages()

        guard case .array(let answers)? = messages.first, messages.count == 1 else { return XCTFail("\(messages)") }
        XCTAssertEqual(answers.map { $0["id"] }, [.string("a"), .null, .string("b")])
        XCTAssertEqual(error(answers[1]), -32600)
    }

    /// A body that is not JSON is answered to the null id, and the connection goes on.
    func testABodyThatIsNotJSONIsAnsweredAndTheConnectionGoesOn() async throws {
        let client = Client()
        try await client.open()
        await client.send(#"{"jsonrpc""#)
        await client.request("1", "test/echo", #"{"text":"after"}"#)
        let messages = try await client.messages()

        XCTAssertEqual(messages[0]["id"], .null)
        XCTAssertEqual(error(messages[0]), -32700)
        XCTAssertEqual(messages[1]["result"], .object(["text": .string("after")]))
    }

    /// Bytes that are no frame end the connection, said on the diagnostics alone.
    func testBytesThatAreNoFrameEndTheConnection() async throws {
        let client = Client()
        let goesOn = await client.connection.receive(Data("Content-Length: x\r\n\r\n{}".utf8))
        XCTAssertFalse(goesOn)
        let messages = try await client.messages()
        XCTAssertEqual(messages, [])
        XCTAssertEqual(client.diagnosed.count, 1)
    }

    /// A slow answer holds no other: a request after it is answered first.
    func testASlowAnswerHoldsNoOther() async throws {
        let client = Client()
        try await client.open()
        await client.request("slow", "test/slow", #"{"text":"slow"}"#)
        await client.request("fast", "test/echo", #"{"text":"fast"}"#)
        let first = try await client.messages(count: 1)
        await client.service.gate.release()
        let then = try await client.messages()

        XCTAssertEqual(first.map { $0["id"] }, [.string("fast")])
        XCTAssertEqual(then.map { $0["id"] }, [.string("slow")])
    }

    /// `shutdown` is answered after every request before it; after it a request is refused, and `exit` ends cleanly.
    func testShutdownIsAnsweredAfterEveryRequestBeforeIt() async throws {
        let client = Client()
        try await client.open()
        await client.request("slow", "test/slow", #"{"text":"slow"}"#)
        await client.request("down", "shutdown")
        await client.request("late", "test/echo", #"{"text":"late"}"#)
        let refused = try await client.messages(count: 1)
        await client.service.gate.release()
        let then = try await client.messages()
        await client.notify("exit")

        XCTAssertEqual(refused.map { $0["id"] }, [.string("late")])
        XCTAssertEqual(error(refused.first), -32003)
        XCTAssertEqual(then.map { $0["id"] }, [.string("slow"), .string("down")])
        let (state, shutDown) = await (client.connection.state, client.connection.shutDown)
        XCTAssertEqual(state, .closed)
        XCTAssertTrue(shutDown)
    }

    /// The connection's end answers every request it accepted before it returns; without `shutdown` it is no clean end.
    func testTheEndAnswersEveryRequestAccepted() async throws {
        let client = Client()
        try await client.open()
        await client.request("slow", "test/slow", #"{"text":"slow"}"#)
        let ended = Task { await client.connection.end() }
        try await Task.sleep(for: .milliseconds(50))
        await client.service.gate.release()
        await ended.value

        let messages = try await client.messages()
        XCTAssertEqual(messages.map { $0["id"] }, [.string("slow")])
        let shutDown = await client.connection.shutDown
        XCTAssertFalse(shutDown)
    }
}
