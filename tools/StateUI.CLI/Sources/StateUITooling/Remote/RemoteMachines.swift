// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A machine whose service this one is paired with: its name here, where its service listens, the id and token this
/// machine proves itself with, and the identity of the machine its service answered for.
public struct RemoteMachine: Codable, Equatable, Sendable {
    public var name: String
    public var address: String
    public var port: UInt16
    public var client: String
    public var token: String
    /// The name its service gave itself.
    public var service: String
    /// The identity its service answered with, which every connection checks; none for a pairing kept before.
    public var identity: String?
    /// The hosts its service builds there, and the machine it runs on, as it said them last.
    public var hosts: [HostPlace] = []
    public var machine: Machine?

    /// The machine `name`, its service at `address` and `port`, proved by `client` and `token`.
    public init(
        name: String, address: String, port: UInt16, client: String, token: String, service: String, identity: String? = nil,
        hosts: [HostPlace] = [], machine: Machine? = nil
    ) {
        (self.name, self.address, self.port, self.client, self.token, self.service) = (name, address, port, client, token, service)
        (self.identity, self.hosts, self.machine) = (identity, hosts, machine)
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
        identity = try fields.decodeIfPresent(String.self, forKey: .identity)
        hosts = try fields.decodeIfPresent([HostPlace].self, forKey: .hosts) ?? []
        machine = try fields.decodeIfPresent(Machine.self, forKey: .machine)
    }

    /// The hosts whose heads run there as its own programs - the destinations this machine reaches it as.
    public var machineHosts: [HostFamily] {
        hosts.filter { $0.place == .machine }.map(\.host)
    }

    /// The hosts whose heads run there on its devices or in its browsers - which this machine reaches through it.
    public var deviceHosts: [HostFamily] {
        hosts.filter { $0.place == .device || $0.place == .browser }.map(\.host)
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
/// application's - out of git and readable by the user alone; none outside a project. A machine its manifest declares
/// is reached at the address and identity declared.
/// Design: docs/design/tooling/service.md#pairing
public struct RemoteMachines: Sendable {
    /// The folder asked for, the project's folder holding it, and the file of its pairings; nil outside a project.
    let folder: URL
    let project: URL?
    let file: URL?

    /// The machines of the project holding `folder`: its workspace's, else its application's.
    public init(project folder: URL) {
        self.folder = folder
        project = Self.projectFolder(holding: folder)
        file = project.map(Self.file(in:))
    }

    /// The machines kept in `file`, of no manifest.
    init(file: URL) {
        (folder, project, self.file) = (file.deletingLastPathComponent(), nil, file)
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

    /// Every machine paired, in the order paired - one the manifest declares at the address and identity declared;
    /// none where the project keeps none.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a file the tool does not read.
    public func list() throws(ToolingError) -> [RemoteMachine] {
        let declared = try self.declared()
        return try kept().map { machine in
            guard let declaration = declared.first(where: { $0.name == machine.name }),
                  let (address, port) = try? ServiceListener.place(declaration.address) else { return machine }
            var meant = machine
            (meant.address, meant.port, meant.identity) = (address, port, declaration.identity)
            return meant
        }
    }

    /// The machine named `name`.
    public func named(_ name: String) throws(ToolingError) -> RemoteMachine? {
        try list().first { $0.name == name }
    }

    /// The machines paired as the project keeps them.
    private func kept() throws(ToolingError) -> [RemoteMachine] {
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try RemotesFile.read(file).machines
    }

    /// The machines the project's manifest declares: its workspace's `stateui-workspace.json`, else its `stateui.json`.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a manifest the tool does not read, or an application of a
    ///   workspace declaring machines of its own.
    public func declared() throws(ToolingError) -> [DeclaredMachine] {
        guard let project else { return [] }
        let workspaceFile = project.appendingPathComponent(WorkspaceFile.name)
        guard FileManager.default.fileExists(atPath: workspaceFile.path) else {
            return try ApplicationFile.read(project.appendingPathComponent(ApplicationFile.name)).remotes ?? []
        }
        let workspace = try WorkspaceFile.read(workspaceFile)
        for path in workspace.projects {
            let file = ApplicationMaker.folder(named: path, from: project).appendingPathComponent(ApplicationFile.name)
            if FileManager.default.fileExists(atPath: file.path), try ApplicationFile.read(file).remotes?.isEmpty == false {
                throw ToolingError(.invalidConfiguration, "\(file.path) declares remotes; in a workspace they stand in its \(WorkspaceFile.name).")
            }
        }
        return workspace.remotes ?? []
    }

    /// Pairs with the service listening on `address` at `port` with the code it shows, and keeps it as `name`; a
    /// machine named so before is replaced. A service answering for another identity than the one the manifest
    /// declares `name` by is refused before its code is spent.
    public func pair(name: String, address: String, port: UInt16, code: String) async throws -> RemoteMachine {
        _ = try projectFile()
        let kept = try self.kept()
        let declaration = try declared().first { $0.name == name }
        let tool = ServedTool(address: address, port: port, workspaceUri: "file:///")
        let identity = try await tool.beforeOpening("service/challenge", .object([:])).decode(Challenge.self).identity
        if let declaration, declaration.identity != identity {
            throw ToolingError(
                .invalidConfiguration,
                "The service at \(address):\(port) answers for \(identity.prefix(12))…, not \(declaration.identity.prefix(12))…, which the project declares \(name) by.")
        }
        let paired = try await tool.beforeOpening(
            "service/pair", try JSONValue(encoding: PairingRequest(code: code, client: ProcessInfo.processInfo.hostName)))
            .decode(PairingResult.self)
        var machine = RemoteMachine(
            name: name, address: address, port: port, client: paired.client, token: paired.token, service: paired.service,
            identity: paired.identity)
        if let info = try? await ServedTool(remote: machine, workspaceUri: "file:///").query("server/info", .object([:])).decode(ServerInfo.self) {
            (machine.hosts, machine.machine) = (info.hosts, info.machine)
        }
        try save(kept.filter { $0.name != name } + [machine])
        return machine
    }

    /// Pairs with the machine the manifest declares as `name`, at its declared address, with the code it shows.
    public func pairDeclared(_ name: String, code: String) async throws -> RemoteMachine {
        guard let declaration = try declared().first(where: { $0.name == name }) else {
            throw ToolingError(.notFound, "The project declares no machine \(name): name where its service listens too.")
        }
        let (address, port) = try ServiceListener.place(declaration.address)
        return try await pair(name: name, address: address, port: port, code: code)
    }

    /// Declares the machine paired as `name` in the project's manifest - its workspace's, else its application's - for
    /// everyone who works on it: its name, address and identity, no secret; the manifest written.
    public func declare(_ name: String) throws -> URL {
        guard let project else { _ = try projectFile(); return folder }
        guard let machine = try kept().first(where: { $0.name == name }) else {
            throw ToolingError(.notFound, "No machine named \(name) is paired with this project: `stateui remote add` pairs it.")
        }
        guard let identity = machine.identity else {
            throw ToolingError(.invalidConfiguration, "\(name) was paired before its service told its identity: pair it again, then declare it.")
        }
        let place = "\(machine.address.contains(":") ? "[\(machine.address)]" : machine.address):\(machine.port)"
        let declaration = DeclaredMachine(name: name, address: place, identity: identity)
        let merged = { (kept: [DeclaredMachine]?) in (kept ?? []).filter { $0.name != name } + [declaration] }
        let workspaceFile = project.appendingPathComponent(WorkspaceFile.name)
        if FileManager.default.fileExists(atPath: workspaceFile.path) {
            var workspace = try WorkspaceFile.read(workspaceFile)
            workspace.remotes = merged(workspace.remotes).sorted { $0.name < $1.name }
            try workspace.write(to: workspaceFile)
            return workspaceFile
        }
        let applicationFile = project.appendingPathComponent(ApplicationFile.name)
        var application = try ApplicationFile.read(applicationFile)
        application.remotes = merged(application.remotes).sorted { $0.name < $1.name }
        try application.write(to: applicationFile)
        return applicationFile
    }

    /// Keeps what `machine`'s service said of itself now: its hosts and its machine.
    public func update(_ name: String, with info: ServerInfo) throws {
        try save(try kept().map { kept in
            guard kept.name == name else { return kept }
            var updated = kept
            (updated.hosts, updated.machine) = (info.hosts, info.machine)
            return updated
        })
    }

    /// Forgets the machine named `name`; whether one was.
    @discardableResult
    public func remove(_ name: String) throws -> Bool {
        let kept = try self.kept()
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
