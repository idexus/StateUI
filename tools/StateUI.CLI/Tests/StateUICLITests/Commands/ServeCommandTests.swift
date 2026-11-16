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

    /// A client that stops reading is lost once more than the limit it may leave unread has stood unread for the
    /// time allowed: the service says so on standard error and ends there as a client lost - its input still open,
    /// its output still unread, a request of its still waiting. The request is called off and the programs it
    /// started stop with it, and a package the client indexed as one host is another connection's to index as another.
    func testAClientThatStopsReadingIsLost() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lost-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (state, package) = (root.appendingPathComponent("state"), root.appendingPathComponent("Notes"))
        for path in ["Package.swift", "Platforms/AppKit/main.swift"] {
            let file = package.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: file)
        }
        try ApplicationFile(identifier: "com.example.notes", version: "1.0.0", build: 1)
            .write(to: package.appendingPathComponent("stateui.json"))
        // Swift asked to describe the package starts a program and waits for it, as a slow manifest does.
        let started = root.appendingPathComponent("descendant")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Stateui.path)
        process.arguments = ["serve", "--stdio"]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "STATEUI_STATE": state.path, "SWIFT_BIN": Stateui.probe, "STATEUI_PROBE_FILE": started.path,
        ]) { $1 }
        let (standardInput, standardOutput, standardError) = (Pipe(), Pipe(), Pipe())
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        defer { if process.isRunning { process.terminate() } }
        let said = Said()
        standardError.fileHandleForReading.readabilityHandler = { said.add($0.availableData) }

        let uri = FileURI.string(package)
        var asked = frame(Self.initialize) + frame(#"{"jsonrpc":"2.0","method":"initialized"}"#)
        asked += frame(#"{"jsonrpc":"2.0","id":"lease","method":"index/acquire","params":{"host":"appkit","rootUris":["\#(uri)"]}}"#)
        asked += frame(#"{"jsonrpc":"2.0","id":"waits","method":"project/describe","params":{"projectUri":"\#(uri)"}}"#)
        for id in 2..<40_002 { asked += frame(#"{"jsonrpc":"2.0","id":\#(id),"method":"server/info"}"#) }
        try standardInput.fileHandleForWriting.write(contentsOf: asked)
        let leases = state.appendingPathComponent("index-leases")
        let leased = {
            let places = (try? FileManager.default.contentsOfDirectory(atPath: leases.path)) ?? []
            return places.contains { place in
                ((try? FileManager.default.contentsOfDirectory(atPath: leases.appendingPathComponent(place).path)) ?? [])
                    .contains { $0.hasPrefix("appkit-") }
            }
        }
        let lost = Date().addingTimeInterval(50)
        while !leased(), Date() < lost { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(leased(), "the client holds the package while it lives")
        let descendant = try Stateui.identifier(writtenTo: started)
        XCTAssertTrue(Stateui.runs(descendant), "the request waits on the program it started")
        while !said.text.contains("is lost"), Date() < lost { try await Task.sleep(for: .milliseconds(250)) }
        XCTAssertTrue(said.text.contains("is lost"), "the client was never lost: \(said.text)")

        let ended = Date().addingTimeInterval(15)
        while process.isRunning, Date() < ended { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(process.isRunning, "the service outlived the client it lost")
        guard !process.isRunning else { return }
        XCTAssertEqual(process.terminationStatus, 6)
        while Stateui.runs(descendant), Date() < ended { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(Stateui.runs(descendant), "a program the request started outlived the client")
        let taken = try await IndexLeases(folder: leases).acquire(.gtk, roots: [package])
        XCTAssertNil(taken.conflict, "what the lost client held is free")
    }

    /// Bytes that are no frame end the service, said on standard error alone.
    func testBytesThatAreNoFrameEndTheService() throws {
        let (status, messages, errors) = try serve(Data("Content-Length: many\r\n\r\n{}".utf8))

        XCTAssertEqual(status, 6)
        XCTAssertEqual(messages, [])
        XCTAssertTrue(errors.contains("no frame"), errors)
    }
}

/// What a stream said, gathered as it comes.
private final class Said: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func add(_ more: Data) { lock.withLock { data.append(more) } }

    var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }
}
