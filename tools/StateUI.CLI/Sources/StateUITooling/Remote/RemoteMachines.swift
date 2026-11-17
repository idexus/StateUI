// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A machine whose service this one is paired with: its name here, where its service listens, and the id and token
/// this machine proves itself with.
public struct RemoteMachine: Codable, Equatable, Sendable {
    public var name: String
    public var address: String
    public var port: UInt16
    public var client: String
    public var token: String
    /// The name its service gave itself.
    public var service: String
    /// The hosts its service builds there, and the machine it runs on, as it said them last.
    public var hosts: [HostPlace] = []
    public var machine: Machine?

    /// The machine `name`, its service at `address` and `port`, proved by `client` and `token`.
    public init(
        name: String, address: String, port: UInt16, client: String, token: String, service: String, hosts: [HostPlace] = [],
        machine: Machine? = nil
    ) {
        (self.name, self.address, self.port, self.client, self.token, self.service) = (name, address, port, client, token, service)
        (self.hosts, self.machine) = (hosts, machine)
    }

    /// A machine as kept, what it said of itself read where kept.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        name = try fields.decode(String.self, forKey: .name)
        address = try fields.decode(String.self, forKey: .address)
        port = try fields.decode(UInt16.self, forKey: .port)
        client = try fields.decode(String.self, forKey: .client)
        token = try fields.decode(String.self, forKey: .token)
        service = try fields.decode(String.self, forKey: .service)
        hosts = try fields.decodeIfPresent([HostPlace].self, forKey: .hosts) ?? []
        machine = try fields.decodeIfPresent(Machine.self, forKey: .machine)
    }

    /// The hosts whose heads run there as its own programs - the destinations this machine reaches it as.
    public var machineHosts: [HostFamily] {
        hosts.filter { $0.place == .machine }.map(\.host)
    }
}

/// The machines a project is paired with, as its `.stateui/remotes.json` holds them.
struct RemotesFile: ToolFile, Equatable {
    static let currentVersion = 1

    var schemaVersion: Int
    var machines: [RemoteMachine]

    init(machines: [RemoteMachine]) {
        schemaVersion = Self.currentVersion
        self.machines = machines
    }
}

/// The machines a project is paired with: kept in its `.stateui/remotes.json` - its workspace's, else its
/// application's - out of git and readable by the user alone; none outside a project.
/// Design: docs/design/tooling/service.md#pairing
public struct RemoteMachines: Sendable {
    /// The folder asked for, and the file of the project holding it; nil outside a project.
    let folder: URL
    let file: URL?

    /// The machines of the project holding `folder`: its workspace's, else its application's.
    public init(project folder: URL) {
        self.folder = folder
        file = Self.projectFolder(holding: folder).map(Self.file(in:))
    }

    /// The machines kept in `file`.
    init(file: URL) {
        (folder, self.file) = (file.deletingLastPathComponent(), file)
    }

    /// Where a project in `folder` keeps them: `.stateui/remotes.json`.
    static func file(in folder: URL) -> URL {
        folder.appendingPathComponent(".stateui").appendingPathComponent("remotes.json")
    }

    /// The project's folder holding `folder`: the nearest workspace up, else the nearest application.
    static func projectFolder(holding folder: URL) -> URL? {
        let real = RealPath.of(RealPath.lexical(folder))
        return (try? Workspace.nearest(from: real))?.folder ?? ProjectReader.application(holding: real)
    }

    /// Every machine paired, in the order paired; none where the project keeps none.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a file the tool does not read.
    public func list() throws(ToolingError) -> [RemoteMachine] {
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try RemotesFile.read(file).machines
    }

    /// The machine named `name`.
    public func named(_ name: String) throws(ToolingError) -> RemoteMachine? {
        try list().first { $0.name == name }
    }

    /// Pairs with the service listening on `address` at `port` with the code it shows, and keeps it as `name`; a
    /// machine named so before is replaced.
    public func pair(name: String, address: String, port: UInt16, code: String) async throws -> RemoteMachine {
        _ = try projectFile()
        let kept = try list()
        let tool = ServedTool(address: address, port: port, workspaceUri: "file:///")
        let paired = try await tool.beforeOpening(
            "service/pair", try JSONValue(encoding: PairingRequest(code: code, client: ProcessInfo.processInfo.hostName)))
            .decode(PairingResult.self)
        var machine = RemoteMachine(
            name: name, address: address, port: port, client: paired.client, token: paired.token, service: paired.service)
        if let info = try? await ServedTool(remote: machine, workspaceUri: "file:///").query("server/info", .object([:])).decode(ServerInfo.self) {
            (machine.hosts, machine.machine) = (info.hosts, info.machine)
        }
        try save(kept.filter { $0.name != name } + [machine])
        return machine
    }

    /// Keeps what `machine`'s service said of itself now: its hosts and its machine.
    public func update(_ name: String, with info: ServerInfo) throws {
        try save(try list().map { kept in
            guard kept.name == name else { return kept }
            var updated = kept
            (updated.hosts, updated.machine) = (info.hosts, info.machine)
            return updated
        })
    }

    /// Forgets the machine named `name`; whether one was.
    @discardableResult
    public func remove(_ name: String) throws -> Bool {
        let kept = try list()
        guard kept.contains(where: { $0.name == name }) else { return false }
        try save(kept.filter { $0.name != name })
        return true
    }

    /// The file the project keeps them in; outside a project, refused before a service is asked.
    func projectFile() throws(ToolingError) -> URL {
        guard let file else {
            throw ToolingError(.projectNotFound, "No StateUI workspace or application stands in or above \(folder.path): a machine is paired for a project.")
        }
        return file
    }

    private func save(_ machines: [RemoteMachine]) throws {
        let file = try projectFile()
        try RemotesFile(machines: machines).write(to: file)
        #if !os(Windows)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #endif
    }
}
