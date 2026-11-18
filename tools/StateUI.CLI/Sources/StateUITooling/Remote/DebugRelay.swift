// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A port of this machine's loopback carrying each connection made to it - LLDB's - to a port of a paired machine's
/// loopback a run's `lldb-server` holds, through that machine's service: the connection challenged and proved as any
/// other, then turned into a pipe. Nothing new listens on the network.
/// Design: docs/design/tooling/service.md#a-debugger-relayed
public final class DebugRelay: Sendable {
    private let listener: StreamSocket

    /// The port of this machine's loopback a debugger connects to.
    public var port: UInt16 { listener.port }

    private init(_ listener: StreamSocket) {
        self.listener = listener
    }

    /// A relay to `port` of `remote`'s loopback, carrying connections until closed.
    public static func open(to remote: RemoteMachine, port: UInt16) throws(ToolingError) -> DebugRelay {
        let listener = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let accepting = Thread {
            while let local = try? listener.accept() {
                let carrying = Thread { carry(local, to: remote, port: port) }
                carrying.name = "stateui relay"
                carrying.start()
            }
        }
        accepting.name = "stateui relay listener"
        accepting.start()
        return DebugRelay(listener)
    }

    /// Stops taking connections; the ones carried end with their ends.
    public func close() {
        listener.close()
    }

    /// `local`'s bytes carried to `port` of `remote`'s loopback through its service, and back, until either end closes.
    private static func carry(_ local: StreamSocket, to remote: RemoteMachine, port: UInt16) {
        defer { local.close() }
        guard let service = try? granted(remote, port: port) else { return }
        let back = Thread {
            while let bytes = try? service.read(), !bytes.isEmpty, (try? local.write(bytes)) != nil {}
            local.close()
        }
        back.name = "stateui relay"
        back.start()
        while let bytes = try? local.read(), !bytes.isEmpty, (try? service.write(bytes)) != nil {}
        service.close()
    }

    /// `remote`'s service connected, its challenge answered with the token - its identity checked first - and the
    /// relay to `port` granted.
    static func granted(_ remote: RemoteMachine, port: UInt16) throws -> StreamSocket {
        let socket = try StreamSocket.connect(to: remote.address, port: remote.port)
        var reader = FrameReader()
        func ask(_ id: String, _ method: String, _ params: JSONValue) throws -> JSONValue {
            let request = JSONValue.object(["jsonrpc": .string("2.0"), "id": .string(id), "method": .string(method), "params": params])
            let body = try ToolingJSON.encoder().encode(request)
            try socket.write(Array("Content-Length: \(body.count)\r\n\r\n".utf8) + Array(body))
            while true {
                let bytes = try socket.read()
                guard !bytes.isEmpty else { throw ToolingError(.toolFailed, "\(remote.name)'s service closed the relay's connection.") }
                for frame in try reader.take(bytes) {
                    guard case .object(let fields) = try ToolingJSON.decoder().decode(JSONValue.self, from: frame),
                          fields["id"] == .string(id) else { continue }
                    if let refusal = fields["error"] { throw ToolingError(.toolFailed, "\(remote.name)'s service refused the relay: \(refusal)") }
                    return fields["result"] ?? .null
                }
            }
        }
        do {
            let challenge = try ask("1", "service/challenge", .object([:])).decode(Challenge.self)
            try ServedTool.check(challenge.identity, of: remote)
            let answer = SHA256.hex(SHA256.hmac(key: Array(remote.token.utf8), message: Array(challenge.nonce.utf8)))
            _ = try ask("2", "service/relay", try JSONValue(encoding: RelayRequest(client: remote.client, answer: answer, port: port)))
            return socket
        } catch {
            socket.close()
            throw error
        }
    }
}
