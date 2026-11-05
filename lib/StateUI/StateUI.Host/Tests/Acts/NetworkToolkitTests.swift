// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import XCTest

final class NetworkToolkitTests: XCTestCase {
    func testRequestsMadeInCodePreserveMethodCase() {
        let names = ["ReadRecord", "READRECORD", "readRecord"]
        let requests = names.map { HostRequest(address: "https://example.com", method: $0) }

        XCTAssertEqual(requests.map(\.method), names)
        XCTAssertNotEqual(requests[0], requests[1])
        XCTAssertEqual(HostRequest(address: "https://example.com").method, "GET")
    }

    func testResponseHeaderValuesKeepProviderOrderAndExistingCommas() {
        let response = HostResponse(status: 200, headers: [
            HostHeader(name: "Vary", value: "User-Agent"),
            HostHeader(name: "Content-Type", value: "text/plain"),
            HostHeader(name: "vary", value: "Accept, Accept-Language"),
            HostHeader(name: "VARY", value: "Accept-Encoding"),
        ], body: [1, 2])

        XCTAssertEqual(response.answer, [
            .number(200),
            .strings(["content-type", "text/plain", "vary", "User-Agent, Accept, Accept-Language, Accept-Encoding"]),
            .bytes([1, 2]),
        ])
    }
}
