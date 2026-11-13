// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import XCTest

final class ServerInfoTests: XCTestCase {
    private let info = ServerInfo(
        server: ToolIdentity(name: "stateui", version: "0.8.4"),
        apiVersions: [APIVersionRange(major: 1, minMinor: 0, maxMinor: 0)],
        machine: Machine(system: "linux", architecture: "x86_64")
    )

    /// A message is written the same, byte for byte, every time: keys sorted, slashes as they are.
    func testAMessageIsWrittenTheSameEveryTime() throws {
        let envelope = Envelope(apiVersion: "1.0", result: info)
        let written = String(decoding: try ToolingJSON.encoder().encode(envelope), as: UTF8.self)

        XCTAssertEqual(written, #"{"apiVersion":"1.0","result":{"apiVersions":[{"major":1,"maxMinor":0,"minMinor":0}],"#
            + #""machine":{"architecture":"x86_64","system":"linux"},"server":{"name":"stateui","version":"0.8.4"}}}"#)
        XCTAssertEqual(try ToolingJSON.decoder().decode(Envelope<ServerInfo>.self, from: Data(written.utf8)), envelope)
    }

    /// A range names its newest version as a message does.
    func testARangeNamesItsNewestVersion() {
        XCTAssertEqual(APIVersionRange(major: 1, minMinor: 0, maxMinor: 3).newest, "1.3")
    }
}
