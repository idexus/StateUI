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
        _ = try file.creatingFolder()
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
        try ApplicationFile(identifier: "com.example.reader", version: "1.0.0", build: 1).write(to: reader.appendingPathComponent(ApplicationFile.name))
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

    private let officeIdentity = String(repeating: "a1", count: 32)
    private let otherIdentity = String(repeating: "b2", count: 32)

    /// A service of this machine, of `identity`, paired as another machine is.
    private func service(_ identity: String, in state: URL) throws -> (ServicePairing, ServiceListener, Task<Void, Never>) {
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients-\(identity.prefix(2)).json"), name: "Office", identity: identity)
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        return (pairing, listener, Task { await listener.serve() })
    }

    /// A machine the manifest declares - a workspace's, else an application's - is reached at the address and the
    /// identity declared, whatever its pairing kept; an application of a workspace declaring its own, or a declaration
    /// the tool does not take, is refused by name.
    func testADeclaredMachineIsReachedAsDeclared() throws {
        let shop = try folder().appendingPathComponent("Shop")
        try ApplicationFile(identifier: "com.example.reader", version: "1.0.0", build: 1)
            .write(to: shop.appendingPathComponent("apps/Reader/\(ApplicationFile.name)").creatingFolder())
        let office = DeclaredMachine(name: "office", address: "192.168.1.30:7980", identity: officeIdentity)
        try WorkspaceFile(projects: ["apps/Reader"], remotes: [office]).write(to: shop.appendingPathComponent(WorkspaceFile.name))
        let remotes = RemoteMachines(project: shop.appendingPathComponent("apps/Reader"))
        XCTAssertEqual(try remotes.declared(), [office])
        try RemotesFile(machines: [self.office(hosts: [])]).write(to: RemoteMachines.file(in: shop))
        let reached = try XCTUnwrap(try remotes.list().first)
        XCTAssertEqual([reached.address, String(reached.port), reached.identity ?? ""], ["192.168.1.30", "7980", officeIdentity])

        try ApplicationFile(identifier: "com.example.reader", version: "1.0.0", build: 1, remotes: [office])
            .write(to: shop.appendingPathComponent("apps/Reader/\(ApplicationFile.name)"))
        XCTAssertThrowsError(try remotes.list()) { error in
            XCTAssertTrue((error as? ToolingError)?.message.contains("in a workspace they stand in") == true, "\(error)")
        }
        let wrong = [
            DeclaredMachine(name: "office", address: "192.168.1.30", identity: officeIdentity),
            DeclaredMachine(name: "office", address: "192.168.1.30:7980", identity: "short"),
        ]
        XCTAssertNotNil(DeclaredMachine.problem(of: [wrong[0]]))
        XCTAssertNotNil(DeclaredMachine.problem(of: [wrong[1]]))
        XCTAssertNotNil(DeclaredMachine.problem(of: [office, office]))
        XCTAssertNil(DeclaredMachine.problem(of: [office]))
    }

    /// Pairing a declared name with a service answering for another identity is refused before its code is spent;
    /// paired, a connection to a service of another identity than the one kept is refused before it proves itself.
    func testAMachineIsKnownByItsIdentity() async throws {
        let state = try folder()
        let shop = state.appendingPathComponent("Shop")
        try ApplicationFile(identifier: "com.example.shop", version: "1.0.0", build: 1, remotes: [
            DeclaredMachine(name: "office", address: "127.0.0.1:1", identity: officeIdentity),
        ]).write(to: shop.appendingPathComponent(ApplicationFile.name).creatingFolder())
        let (pairing, listener, serving) = try service(otherIdentity, in: state)
        defer { serving.cancel() }
        let remotes = RemoteMachines(project: shop)
        do {
            _ = try await remotes.pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
            XCTFail("another identity paired as office")
        } catch let error as ToolingError {
            XCTAssertTrue(error.message.contains("which the project declares office by"), error.message)
        }
        let studio = try await remotes.pair(name: "studio", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertEqual(studio.identity, otherIdentity, "the code was not spent, and the identity is kept")

        var moved = studio
        moved.identity = officeIdentity
        do {
            _ = try await ServedTool(remote: moved, workspaceUri: "file:///").query("server/info", .object([:]))
            XCTFail("a service of another identity was answered")
        } catch let error as ToolingError {
            XCTAssertTrue(error.message.contains("Another machine answers"), error.message)
        }
        let probed = await ServiceProbe.check(moved)
        XCTAssertEqual(probed, .anotherMachine(
            "Another machine answers at 127.0.0.1:\(listener.port): its identity is \(otherIdentity.prefix(12))…, not \(officeIdentity.prefix(12))…, studio's. Where it is that machine set up anew, pair it again."))
    }

    /// Declaring a machine paired writes its name, address and identity - no token - into the project's manifest, the
    /// machines sorted; a machine paired so is paired again by its name alone, at the address declared.
    func testDeclaringAMachineWritesTheManifest() async throws {
        let state = try folder()
        let shop = state.appendingPathComponent("Shop")
        let manifest = shop.appendingPathComponent(ApplicationFile.name)
        try ApplicationFile(identifier: "com.example.shop", version: "1.0.0", build: 1).write(to: manifest.creatingFolder())
        let (pairing, listener, serving) = try service(officeIdentity, in: state)
        defer { serving.cancel() }
        let remotes = RemoteMachines(project: shop)
        _ = try await remotes.pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertEqual(try remotes.declare("office"), manifest)
        let written = try String(contentsOf: manifest, encoding: .utf8)
        XCTAssertTrue(written.contains(officeIdentity) && written.contains("127.0.0.1:\(listener.port)"), written)
        XCTAssertFalse(written.contains("token"), written)
        XCTAssertEqual(try remotes.declared().map(\.name), ["office"])

        XCTAssertTrue(try remotes.remove("office"))
        let again = try await remotes.pairDeclared("office", code: pairing.code)
        XCTAssertEqual([again.address, String(again.port)], ["127.0.0.1", String(listener.port)])
        XCTAssertThrowsError(try remotes.declare("nobody"))
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
        XCTAssertTrue(destination.debugger, "through its service")
    }

    /// The machines paired with a project are told to its clients: in the server's information, and as the
    /// destinations of the hosts they run.
    func testAProjectsPairedMachinesAreToldToItsClients() async throws {
        let shop = try folder().appendingPathComponent("Shop")
        try ApplicationFile(identifier: "com.example.shop", version: "1.0.0", build: 1).write(to: shop.appendingPathComponent(ApplicationFile.name))
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

private extension URL {
    /// The file, its folder made where none stands.
    func creatingFolder() throws -> URL {
        try FileManager.default.createDirectory(at: deletingLastPathComponent(), withIntermediateDirectories: true)
        return self
    }
}
