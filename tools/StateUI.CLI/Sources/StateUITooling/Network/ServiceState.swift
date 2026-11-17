// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What a running service says of itself to its own machine, in its user's state folder, readable by the user alone:
/// where it listens, the pairing code it shows now and the machine's identity - what `stateui service status` tells, the service running in
/// the background where no one reads its output.
/// Design: docs/design/tooling/service.md#the-service-in-the-background
public struct ServiceState: Codable, Equatable, Sendable {
    /// The service's process.
    public var process: Int32
    public var address: String
    public var port: UInt16
    public var code: String
    public var codeUntil: Date
    /// The identity of the machine it serves, which a project's manifest names it by; none in a state written before.
    public var identity: String?

    /// The service of `process` listening on `address` at `port`, showing `code` until `codeUntil`, of `identity`.
    public init(
        process: Int32 = ProcessInfo.processInfo.processIdentifier, address: String, port: UInt16, code: String, codeUntil: Date,
        identity: String? = nil
    ) {
        self.process = process
        self.address = address
        self.port = port
        self.code = code
        self.codeUntil = codeUntil
        self.identity = identity
    }

    /// Where the running service keeps it.
    public static var file: URL { BuildPermit.userFolder.appendingPathComponent("service/state.json") }

    /// Writes it to `file`.
    public func write(to file: URL = ServiceState.file) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: file, options: .atomic)
        #if !os(Windows)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #endif
    }

    /// What the service of this machine said last, where one answers at the port it said; nil where none runs.
    public static func running(in file: URL = ServiceState.file) -> ServiceState? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(ServiceState.self, from: Data(contentsOf: file)) else { return nil }
        let reached = ["0.0.0.0", "::"].contains(state.address) ? "127.0.0.1" : state.address
        guard let socket = try? StreamSocket.connect(to: reached, port: state.port) else { return nil }
        socket.close()
        return state
    }
}
