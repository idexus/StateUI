// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import XCTest

final class IncomingMessageTests: XCTestCase {
    private func body(_ json: String) -> IncomingBody { IncomingBody(Data(json.utf8)) }

    /// A request keeps its id's type; a message without an id is a notification.
    func testARequestKeepsItsIdsTypeAndANotificationHasNone() {
        XCTAssertEqual(
            body(#"{"jsonrpc":"2.0","id":"a-1","method":"server/info","params":{}}"#),
            .single(.request(id: .string("a-1"), method: "server/info", params: .object([:]))))
        XCTAssertEqual(
            body(#"{"jsonrpc":"2.0","id":7,"method":"server/info"}"#),
            .single(.request(id: .number(7), method: "server/info", params: nil)))
        XCTAssertEqual(
            body(#"{"jsonrpc":"2.0","method":"initialized","params":{}}"#),
            .single(.notification(method: "initialized", params: .object([:]))))
    }

    /// A body that is not JSON, or an empty batch, is answered once, to the null id.
    func testABodyThatIsNotAMessageIsUnreadable() {
        guard case .unreadable(let error) = body(#"{"jsonrpc":"2.0","#) else { return XCTFail() }
        XCTAssertEqual(error.code, -32700)
        guard case .unreadable(let empty) = body("[]") else { return XCTFail() }
        XCTAssertEqual(empty.code, -32600)
    }

    /// A message that is not a request is invalid, answered to its id where one can be read.
    func testAMessageThatIsNotARequestIsInvalid() {
        let invalid = [
            (#"{"id":1,"method":"x"}"#, RequestID?.some(.number(1))),
            (#"{"jsonrpc":"1.0","id":1,"method":"x"}"#, .number(1)),
            (#"{"jsonrpc":"2.0","id":1,"method":3}"#, .number(1)),
            (#"{"jsonrpc":"2.0","id":1,"method":"x","params":3}"#, .number(1)),
            (#"{"jsonrpc":"2.0","id":1,"method":"x","extra":true}"#, .number(1)),
            (#"{"jsonrpc":"2.0","id":{},"method":"x"}"#, nil),
            (#"{"jsonrpc":"2.0","id":2}"#, .number(2)),
            ("3", nil),
        ]
        for (json, id) in invalid {
            guard case .single(.invalid(let read, let error)) = body(json) else { XCTFail(json); continue }
            XCTAssertEqual(read, id, json)
            XCTAssertEqual(error.code, -32600, json)
        }
    }

    /// A batch is its messages, each read on its own.
    func testABatchIsItsMessagesEachReadOnItsOwn() {
        XCTAssertEqual(
            body(#"[{"jsonrpc":"2.0","id":"1","method":"a"},{"jsonrpc":"2.0","method":"b"},5]"#),
            .batch([
                .request(id: .string("1"), method: "a", params: nil),
                .notification(method: "b", params: nil),
                .invalid(id: nil, error: .invalidRequest("A message is a JSON object.")),
            ]))
    }

    /// A client's answer is read as an answer.
    func testAClientsAnswerIsAnAnswer() {
        XCTAssertEqual(body(#"{"jsonrpc":"2.0","id":"s-1","result":null}"#), .single(.response(id: .string("s-1"))))
    }

    /// An answer is written with its id's own type, and exactly one of a result or an error.
    func testAnAnswerIsWrittenWithItsIdsType() throws {
        let answers = OutgoingMessage.batch([
            .response(id: .number(7), outcome: .result(.null)),
            .response(id: .string("x"), outcome: .error(.methodNotFound("nope"))),
        ])
        XCTAssertEqual(
            String(decoding: try ToolingJSON.encoder().encode(answers), as: UTF8.self),
            #"[{"id":7,"jsonrpc":"2.0","result":null},"#
                + #"{"error":{"code":-32601,"message":"No method nope."},"id":"x","jsonrpc":"2.0"}]"#)
    }
}
