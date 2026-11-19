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
    /// a query, and a folder carried over one connection.
    func testAPairedMachineIsAnsweredQueriesAndOperations() async throws {
        let state = folder()
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let remotes = RemoteMachines(file: state.appendingPathComponent("remotes.json"))
        let machine = try await remotes.pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertEqual(try remotes.list().map(\.name), ["office"])
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
        let carried = try await tool.session { session in
            try await FolderTransfer.send(root.appendingPathComponent("from"), files: nil, to: root.appendingPathComponent("to").path, over: session, progress: { _ in })
        }
        XCTAssertEqual(carried.carried, 1)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("to/A.swift"), encoding: .utf8), "a")
    }

    /// A client not paired - or paired with a code the service does not show - is refused; cancelled, the service
    /// stops listening.
    func testAClientNotPairedIsRefusedUntilTheServiceStops() async throws {
        let state = folder()
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
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

    /// A client found lost reads nothing: its connection ends without waiting for it to take what was sent - the frames
    /// still unwritten fail as its socket shuts - while every frame reaches a client that reads.
    func testALostClientsConnectionEndsWithoutIt() throws {
        let listening = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { listening.close() }
        let peer = try StreamSocket.connect(to: "127.0.0.1", port: listening.port)
        defer { peer.close() }
        let client = try listening.accept()
        let writer = SocketWriter(client)
        writer.write(Data(count: 64 << 20))
        let ended = DispatchSemaphore(value: 0)
        let ending = Thread { ServiceListener.end(client, writer: writer, lost: true); ended.signal() }
        ending.start()
        let done = ended.wait(timeout: .now() + 5) == .success
        if !done { client.close() }
        XCTAssertTrue(done, "the end waited for a client that reads nothing")
    }
}
