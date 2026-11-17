// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ServiceListenerTests: XCTestCase {
    /// The service answers the protocol over TCP as `serve --stdio` does: a query, then an operation followed to its
    /// end, each on a connection of its own.
    func testTheServiceAnswersQueriesAndOperations() async throws {
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let tool = ServedTool(address: "127.0.0.1", port: listener.port, workspaceUri: "file:///")

        let info = try await tool.query("server/info", .object([:])).decode(ServerInfo.self)
        XCTAssertEqual(info.server.name, "stateui")
        XCTAssertEqual(info.hosts, HostPlaces.here)

        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("service-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try files.createDirectory(at: root.appendingPathComponent("from"), withIntermediateDirectories: true)
        try "a".write(to: root.appendingPathComponent("from/A.swift"), atomically: true, encoding: .utf8)
        let mirrored = try await tool.operation("folder/mirror", try JSONValue(encoding: FolderMirrorRequest(
            sourcePath: root.appendingPathComponent("from").path, targetPath: root.appendingPathComponent("to").path, files: nil)),
            reporter: BuildReporter()).decode(FolderMirrorResult.self)
        XCTAssertEqual(mirrored.copied, 1)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("to/A.swift"), encoding: .utf8), "a")
    }

    /// The service listens on this machine's loopback alone; cancelled, it stops listening.
    func testItListensOnTheLoopbackAloneUntilCancelled() async throws {
        XCTAssertThrowsError(try ServiceListener.open(on: "0.0.0.0", port: 0)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
        }
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0)
        let serving = Task { await listener.serve() }
        serving.cancel()
        await serving.value
        XCTAssertThrowsError(try StreamSocket.connect(to: "127.0.0.1", port: listener.port))
    }
}
