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

    /// A relay to `port` of `remote`'s loopback, carrying connections until closed - a debug adapter's messages with
    /// their paths translated where `translation` is given.
    public static func open(to remote: RemoteMachine, port: UInt16, translation: PathTranslation? = nil) throws(ToolingError) -> DebugRelay {
        let listener = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let accepting = Thread {
            while let local = try? listener.accept() {
                let carrying = Thread { carry(local, to: remote, port: port, translation: translation) }
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

    /// `local`'s bytes carried to `port` of `remote`'s loopback through its service, and back, until either end closes -
    /// as messages whose paths `translation` turns, where given.
    private static func carry(_ local: StreamSocket, to remote: RemoteMachine, port: UInt16, translation: PathTranslation?) {
        defer { local.close() }
        let service: StreamSocket
        do {
            service = try granted(remote, port: port)
        } catch {
            // The editor sees a closed connection alone: the reason goes where the tool's words go.
            try? FileHandle.standardError.write(contentsOf: Data("stateui: the relay to \(remote.name) was not granted: \(error)\n".utf8))
            return
        }
        let back = Thread {
            pipe(from: service, to: local, translation: translation, toward: .here)
            local.close()
        }
        back.name = "stateui relay"
        back.start()
        pipe(from: local, to: service, translation: translation, toward: .there)
        service.close()
    }

    /// What `source` says, written to `target` until either closes: as it comes, or message by message - each a
    /// `Content-Length` frame - with its paths translated `direction`.
    private static func pipe(from source: StreamSocket, to target: StreamSocket, translation: PathTranslation?, toward direction: PathTranslation.Direction) {
        guard let translation else {
            while let bytes = try? source.read(), !bytes.isEmpty, (try? target.write(bytes)) != nil {}
            return
        }
        var reader = FrameReader()
        while let bytes = try? source.read(), !bytes.isEmpty, let frames = try? reader.take(bytes) {
            for frame in frames {
                guard let message = try? ToolingJSON.decoder().decode(JSONValue.self, from: frame),
                      let body = try? ToolingJSON.encoder().encode(translation.translated(message, toward: direction)),
                      (try? target.write(Array("Content-Length: \(body.count)\r\n\r\n".utf8) + Array(body))) != nil else { return }
            }
        }
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

/// The paths a debug adapter's messages name, turned from this machine's into the other's on the way there and back
/// again: a source under `here` stands under `there`, written as that machine writes a path.
public struct PathTranslation: Sendable, Equatable {
    /// Which way a message goes.
    public enum Direction: Sendable {
        case there, here
    }

    let here: String
    let there: String
    let windows: Bool

    /// The translation of the folder `here` of this machine, copied to `there` on a machine writing paths as Windows
    /// does where `windows`.
    public init(here: String, there: String, windows: Bool) {
        (self.here, self.there, self.windows) = (here, there, windows)
    }

    /// `value` with each `path` under the folder of the side it leaves translated to the other's.
    func translated(_ value: JSONValue, toward direction: Direction) -> JSONValue {
        switch value {
        case .object(let fields):
            return .object(fields.reduce(into: [:]) { result, field in
                if field.key == "path", case .string(let path) = field.value, let moved = moved(path, toward: direction) {
                    result[field.key] = .string(moved)
                } else {
                    result[field.key] = translated(field.value, toward: direction)
                }
            })
        case .array(let items):
            return .array(items.map { translated($0, toward: direction) })
        default:
            return value
        }
    }

    /// `path` under the folder of the side it leaves, as the same file under the other's; nil for any other path.
    private func moved(_ path: String, toward direction: Direction) -> String? {
        let (separator, theirs) = (windows ? "\\" : "/", windows ? path.replacingOccurrences(of: "/", with: "\\") : path)
        switch direction {
        case .there:
            guard path == here || path.hasPrefix(here + "/") else { return nil }
            let rest = String(path.dropFirst(here.count))
            return there + (windows ? rest.replacingOccurrences(of: "/", with: "\\") : rest)
        case .here:
            let start = theirs.prefix(there.count)
            let same = windows ? start.lowercased() == there.lowercased() : start == there
            guard same, theirs.count == there.count || theirs.dropFirst(there.count).hasPrefix(separator) else { return nil }
            let rest = String(theirs.dropFirst(there.count))
            return here + (windows ? rest.replacingOccurrences(of: "\\", with: "/") : rest)
        }
    }
}
