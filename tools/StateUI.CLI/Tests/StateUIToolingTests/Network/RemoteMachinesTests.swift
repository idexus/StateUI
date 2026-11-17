// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class RemoteMachinesTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = RealPath.of(FileManager.default.temporaryDirectory.appendingPathComponent("remotes-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return RealPath.of(folder)
    }

    private func write(_ text: String, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func office(hosts: [HostPlace]) -> RemoteMachine {
        RemoteMachine(
            name: "office", address: "192.168.1.20", port: 7979, client: "c1", token: "t1", service: "OFFICE", hosts: hosts,
            machine: Machine(system: "windows", architecture: "arm64"))
    }

    /// A project's paired machines stand in its own `.stateui`, out of git: its workspace's where one stands, else its
    /// application's; outside a project none is read, and a pairing is refused before any service is asked.
    func testPairedMachinesStandInTheirProject() async throws {
        let root = try folder()
        let shop = root.appendingPathComponent("Shop")
        let reader = shop.appendingPathComponent("apps/Reader")
        try write("{}", to: reader.appendingPathComponent(ApplicationFile.name))
        XCTAssertEqual(RemoteMachines(project: reader.appendingPathComponent("Sources")).file, reader.appendingPathComponent(".stateui/remotes.json"))

        try WorkspaceFile(projects: ["apps/Reader"]).write(to: shop.appendingPathComponent(WorkspaceFile.name))
        XCTAssertEqual(RemoteMachines(project: reader).file, shop.appendingPathComponent(".stateui/remotes.json"))

        let outside = RemoteMachines(project: root)
        XCTAssertNil(outside.file)
        XCTAssertEqual(try outside.list(), [])
        do {
            _ = try await outside.pair(name: "office", address: "127.0.0.1", port: 1, code: "000000")
            XCTFail("a pairing outside a project")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .projectNotFound)
        }
    }

    /// The file is the tool's - a form version, what it does not read refused by name - written the same every time
    /// and readable by its user alone.
    func testTheFileIsTheToolsAndItsUsersAlone() throws {
        let file = try folder().appendingPathComponent(".stateui/remotes.json")
        let remotes = RemoteMachines(file: file)
        let machine = office(hosts: [HostPlace(host: .winui, place: .machine)])
        try RemotesFile(machines: [machine]).write(to: file)
        XCTAssertEqual(try remotes.list(), [machine])
        XCTAssertTrue(try remotes.remove("office"))
        XCTAssertEqual(try remotes.list(), [])
        #if !os(Windows)
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        #endif

        try write(#"{"schemaVersion": 1, "machines": [], "paired": true}"#, to: file)
        XCTAssertThrowsError(try remotes.list()) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
            XCTAssertTrue((error as? ToolingError)?.message.contains("paired") == true, "\(error)")
        }
    }

    /// A machine paired is the destination of the heads that run there as its own programs - not of those it runs on
    /// its devices, in its browsers or its own guests; they are told beside this machine's own hosts at `remote`.
    func testAPairedMachineOffersTheHostsItRunsAsItsOwnPrograms() {
        let mac = office(hosts: [
            HostPlace(host: .appkit, place: .machine), HostPlace(host: .uikit, place: .device), HostPlace(host: .gtk, place: .guest),
            HostPlace(host: .web, place: .browser),
        ])
        XCTAssertEqual(mac.machineHosts, [.appkit])
        let windows = office(hosts: [HostPlace(host: .winui, place: .machine)])
        let available = HostPlaces.available(remotes: [mac, windows])
        let own = Set(HostPlaces.here.map(\.host))
        for host in [HostFamily.appkit, .winui] where !own.contains(host) {
            XCTAssertTrue(available.contains(HostPlace(host: host, place: .remote)), "\(host)")
        }
        XCTAssertEqual(available.filter { own.contains($0.host) }, HostPlaces.here, "this machine's own place stands first")
        XCTAssertEqual(available.map(\.host), available.map(\.host).sorted(), "in the matrix's order")

        let destination = HostPlaces.remote(windows)
        XCTAssertEqual(destination.kind, .remote)
        XCTAssertEqual(destination.id, "office")
        XCTAssertEqual(destination.connection, "192.168.1.20:7979")
        XCTAssertEqual(destination.architecture, .arm64)
        XCTAssertEqual(destination.emulated, [.x86_64])
        XCTAssertFalse(destination.debugger)
    }

    /// The machines paired with a project are told to its clients: in the server's information, and as the
    /// destinations of the hosts they run.
    func testAProjectsPairedMachinesAreToldToItsClients() async throws {
        let shop = try folder().appendingPathComponent("Shop")
        try write("{}", to: shop.appendingPathComponent(ApplicationFile.name))
        let windows = office(hosts: [HostPlace(host: .winui, place: .machine)])
        try RemotesFile(machines: [windows]).write(to: RemoteMachines.file(in: shop))

        let info = ToolingService().serverInfo(in: shop)
        XCTAssertTrue(info.hosts.contains { $0.host == .winui })
        XCTAssertEqual(ToolingService().serverInfo().hosts, HostPlaces.here)
        let listed = try await ToolingService().listDestinations(of: .winui, in: shop)
        XCTAssertEqual(listed.destinations.last?.kind, .remote)
        XCTAssertEqual(listed.destinations.filter { $0.kind == .remote }.map(\.name), ["office"])
    }
}
