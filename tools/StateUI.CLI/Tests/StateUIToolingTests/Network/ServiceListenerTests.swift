// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ServiceListenerTests: XCTestCase {
    private func folder() -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("service-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A machine pairs with the code the service shows; then the service answers it over TCP as `serve --stdio` does:
    /// a query, then an operation followed to its end, each on a connection of its own.
    func testAPairedMachineIsAnsweredQueriesAndOperations() async throws {
        let state = folder()
        let pairing = ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let remotes = RemoteMachines(file: state.appendingPathComponent("remotes.json"))
        let machine = try await remotes.pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertEqual(remotes.list().map(\.name), ["office"])
        XCTAssertEqual(machine.service, "Office")
        let tool = ServedTool(remote: machine, workspaceUri: "file:///")

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

    /// A client not paired - or paired with a code the service does not show - is refused; cancelled, the service
    /// stops listening.
    func testAClientNotPairedIsRefusedUntilTheServiceStops() async throws {
        let state = folder()
        let pairing = ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        do {
            _ = try await ServedTool(address: "127.0.0.1", port: listener.port, workspaceUri: "file:///").query("server/info", .object([:]))
            XCTFail("a client not paired was answered")
        } catch let error as ToolingError {
            XCTAssertTrue(error.message.contains("not paired"), error.message)
        }
        do {
            _ = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
                .pair(name: "office", address: "127.0.0.1", port: listener.port, code: "wrong")
            XCTFail("a wrong code paired")
        } catch let error as ToolingError {
            XCTAssertTrue(error.message.contains("not the pairing code"), error.message)
        }
        serving.cancel()
        await serving.value
        XCTAssertThrowsError(try StreamSocket.connect(to: "127.0.0.1", port: listener.port))
    }
}
