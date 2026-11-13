// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ServeCommandTests: XCTestCase {
    private static let initialize = #"{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"#
        + #""apiVersions":[{"major":1,"minMinor":0,"maxMinor":0}],"client":{"name":"test","version":"1"},"#
        + #""workspaceUri":"file:///w"}}"#

    private func frame(_ json: String) -> Data {
        Data(("Content-Length: \(json.utf8.count)\r\n\r\n" + json).utf8)
    }

    /// Runs `stateui serve --stdio` given `input` - then its input closed - and gives its status, the messages on
    /// its standard output and what it wrote on standard error.
    private func serve(_ input: Data) throws -> (status: Int32, messages: [JSONValue], errors: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Stateui.path)
        process.arguments = ["serve", "--stdio"]
        let (standardInput, standardOutput, standardError) = (Pipe(), Pipe(), Pipe())
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        try standardInput.fileHandleForWriting.write(contentsOf: input)
        try standardInput.fileHandleForWriting.close()
        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errors = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        var reader = FrameReader()
        let messages = try reader.take(output).map { try ToolingJSON.decoder().decode(JSONValue.self, from: $0) }
        return (process.terminationStatus, messages, String(decoding: errors, as: UTF8.self))
    }

    /// A connection opened, asked, shut down and exited ends with status 0, its output frames alone.
    func testAConnectionShutDownEndsCleanly() throws {
        let (status, messages, _) = try serve(
            frame(Self.initialize)
                + frame(#"{"jsonrpc":"2.0","method":"initialized"}"#)
                + frame(#"{"jsonrpc":"2.0","id":2,"method":"server/info"}"#)
                + frame(#"{"jsonrpc":"2.0","id":"3","method":"shutdown"}"#)
                + frame(#"{"jsonrpc":"2.0","method":"exit"}"#))

        XCTAssertEqual(status, 0)
        XCTAssertEqual(messages.count, 3)
        let info = try JSONValue(encoding: ToolingService().serverInfo())
        XCTAssertTrue(messages.contains(.object(["jsonrpc": .string("2.0"), "id": .number(2), "result": info])))
        XCTAssertEqual(messages.last, .object(["jsonrpc": .string("2.0"), "id": .string("3"), "result": .null]))
    }

    /// An input ending with no `shutdown` is a client lost: status 6, every request accepted answered.
    func testAnInputEndingWithoutShutdownIsAClientLost() throws {
        let (status, messages, _) = try serve(
            frame(Self.initialize) + frame(#"{"jsonrpc":"2.0","method":"initialized"}"#)
                + frame(#"{"jsonrpc":"2.0","id":2,"method":"server/info"}"#))

        XCTAssertEqual(status, 6)
        XCTAssertEqual(messages.count, 2)
    }

    /// Bytes that are no frame end the service, said on standard error alone.
    func testBytesThatAreNoFrameEndTheService() throws {
        let (status, messages, errors) = try serve(Data("Content-Length: many\r\n\r\n{}".utf8))

        XCTAssertEqual(status, 6)
        XCTAssertEqual(messages, [])
        XCTAssertTrue(errors.contains("no frame"), errors)
    }
}
