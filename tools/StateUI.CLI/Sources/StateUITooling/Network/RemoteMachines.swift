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
}

/// The machines this one is paired with, kept in the user's state folder, readable by the user alone.
/// Design: docs/design/tooling/service.md#pairing
public struct RemoteMachines: Sendable {
    let file: URL

    /// The machines kept in `file`.
    public init(file: URL = BuildPermit.userFolder.appendingPathComponent("remotes.json")) {
        self.file = file
    }

    /// Every machine paired, in the order paired.
    public func list() -> [RemoteMachine] {
        (try? JSONDecoder().decode([RemoteMachine].self, from: Data(contentsOf: file))) ?? []
    }

    /// The machine named `name`.
    public func named(_ name: String) -> RemoteMachine? {
        list().first { $0.name == name }
    }

    /// Pairs with the service listening on `address` at `port` with the code it shows, and keeps it as `name`; a
    /// machine named so before is replaced.
    public func pair(name: String, address: String, port: UInt16, code: String) async throws -> RemoteMachine {
        let tool = ServedTool(address: address, port: port, workspaceUri: "file:///")
        let paired = try await tool.beforeOpening(
            "service/pair", try JSONValue(encoding: PairingRequest(code: code, client: ProcessInfo.processInfo.hostName)))
            .decode(PairingResult.self)
        let machine = RemoteMachine(
            name: name, address: address, port: port, client: paired.client, token: paired.token, service: paired.service)
        try save(list().filter { $0.name != name } + [machine])
        return machine
    }

    /// Forgets the machine named `name`; whether one was.
    @discardableResult
    public func remove(_ name: String) throws -> Bool {
        let kept = list()
        guard kept.contains(where: { $0.name == name }) else { return false }
        try save(kept.filter { $0.name != name })
        return true
    }

    private func save(_ machines: [RemoteMachine]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(machines).write(to: file, options: .atomic)
        #if !os(Windows)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #endif
    }
}
