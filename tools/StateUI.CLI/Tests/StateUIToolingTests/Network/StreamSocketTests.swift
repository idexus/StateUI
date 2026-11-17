// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class StreamSocketTests: XCTestCase {
    /// A socket listening on a free port is reached by a connection: what each end writes the other reads, and once
    /// one end closes the other reads nothing more.
    func testAConnectionCarriesBytesBothWaysUntilItCloses() async throws {
        let listener = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { listener.close() }
        XCTAssertNotEqual(listener.port, 0)
        let accepted = Task.detached { try listener.accept() }
        let client = try StreamSocket.connect(to: "127.0.0.1", port: listener.port)
        let server = try await accepted.value
        try client.write(Array("Content-Length: 2\r\n\r\n{}".utf8))
        var heard: [UInt8] = []
        while heard.count < 23 { heard += try server.read() }
        XCTAssertEqual(String(decoding: heard, as: UTF8.self), "Content-Length: 2\r\n\r\n{}")
        try server.write(Array("ok".utf8))
        XCTAssertEqual(try client.read(), Array("ok".utf8))
        client.close()
        XCTAssertEqual(try server.read(), [])
        server.close()
    }

    /// A place no machine is named by is refused as a configuration, and a port nothing listens on as a failure to
    /// connect.
    func testWhatCannotBeReachedIsSaid() throws {
        XCTAssertThrowsError(try StreamSocket.connect(to: "no-such-machine.invalid", port: 7979)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
        }
        let free = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let port = free.port
        free.close()
        XCTAssertThrowsError(try StreamSocket.connect(to: "127.0.0.1", port: port)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .toolFailed)
        }
    }
}
