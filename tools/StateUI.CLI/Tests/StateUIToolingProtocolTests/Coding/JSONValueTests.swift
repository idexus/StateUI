// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import XCTest

final class JSONValueTests: XCTestCase {
    private struct Parameters: Codable, Equatable {
        var name: String
        var count: Int?
        var inner: Inner?
    }

    private struct Inner: Codable, Equatable {
        var flag: Bool
    }

    private func value(_ json: String) throws -> JSONValue {
        try ToolingJSON.decoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    /// Every kind of value is read as itself: true is no number, 1 no boolean.
    func testEveryKindIsReadAsItself() throws {
        XCTAssertEqual(
            try value(#"[null,true,1,1.5,"x",[],{"a":false}]"#),
            .array([.null, .bool(true), .number(1), .number(1.5), .string("x"), .array([]), .object(["a": .bool(false)])]))
    }

    /// A value read whole is its type.
    func testAValueReadWholeIsItsType() throws {
        XCTAssertEqual(
            try value(#"{"name":"a","count":2,"inner":{"flag":true}}"#).decode(Parameters.self),
            Parameters(name: "a", count: 2, inner: Inner(flag: true)))
        XCTAssertEqual(try value(#"{"name":"a"}"#).decode(Parameters.self), Parameters(name: "a"))
    }

    /// A field the type does not declare - at any depth - or null for an optional one is refused, by where it stands.
    func testWhatTheTypeDoesNotReadIsRefused() throws {
        let refused = [
            (#"{"name":"a","extra":1}"#, ["/extra"]),
            (#"{"name":"a","inner":{"flag":true,"more":[1]}}"#, ["/inner/more"]),
            (#"{"name":"a","count":null}"#, ["/count"]),
        ]
        for (json, unread) in refused {
            XCTAssertThrowsError(try value(json).decode(Parameters.self), json) {
                XCTAssertEqual(($0 as? StrictDecodingError)?.unread, unread, json)
            }
        }
    }

    /// A value missing what its type needs is refused by the decoder.
    func testAValueMissingAFieldIsRefused() throws {
        XCTAssertThrowsError(try value(#"{"count":2}"#).decode(Parameters.self)) {
            XCTAssertTrue($0 is DecodingError)
        }
    }
}
