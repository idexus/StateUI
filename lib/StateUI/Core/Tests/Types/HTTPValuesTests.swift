// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
import XCTest

final class HTTPValuesTests: XCTestCase {
    func testSyntheticHeaderCaseCollisionsHaveOneValueForEveryInsertionOrder() {
        let fields = [("X-Trace", "first, preserved"), ("X-tRace", "middle"), ("x-trace", "last")]
        let orders = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
        let body = Array("An answer".utf8)
        let expected = HTTPResponse(
            status: 206, headers: ["x-trace": "first, preserved, middle, last"], body: body)
        var responses: Set<HTTPResponse> = []

        for order in orders {
            for _ in 0..<32 {
                let headers = Dictionary(uniqueKeysWithValues: order.map { fields[$0] })
                responses.insert(HTTPResponse(status: 206, headers: headers, body: body))
            }
        }

        XCTAssertEqual(responses, [expected], "case variants combine in original-name UTF-8 order")
        XCTAssertEqual(expected.header("X-TRACE"), "first, preserved, middle, last")
        XCTAssertEqual(expected.headers.keys.sorted(), ["x-trace"])
        XCTAssertEqual(expected.text, "An answer")
    }

    func testCustomMethodNamesKeepTheirCaseAndRemainDistinct() {
        let mixed = HTTPMethod("ReadRecord")
        let uppercase = HTTPMethod("READRECORD")

        XCTAssertEqual(mixed.name, "ReadRecord")
        XCTAssertEqual(uppercase.name, "READRECORD")
        XCTAssertNotEqual(mixed, uppercase)
        XCTAssertEqual(Set([mixed, uppercase]).count, 2)
        XCTAssertEqual(HTTPRequest("https://example.com", method: mixed).method, mixed)
    }

    func testNamedStandardMethodsKeepTheirStandardNames() {
        let methods: [HTTPMethod] = [.get, .post, .put, .patch, .delete, .head]

        XCTAssertEqual(methods.map(\.name), ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"])
        XCTAssertEqual(HTTPRequest("https://example.com").method, .get)
    }
}
