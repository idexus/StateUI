// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import Foundation
import StateUIToolingProtocol
import Synchronization

/// The tool's service: clients connected over TCP, each served as `serve --stdio` serves one over standard streams -
/// the protocol's connection, the tool's methods. It listens on this machine's loopback alone.
/// Design: docs/design/tooling/service.md#the-service-listening
public struct ServiceListener: Sendable {
    private let socket: StreamSocket

    /// The port it listens on.
    public var port: UInt16 { socket.port }

    /// A service listening on `address` at `port`, any free one for 0.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for an address other than this machine's loopback.
    public static func open(on address: String, port: UInt16) throws(ToolingError) -> ServiceListener {
        guard ["127.0.0.1", "::1", "localhost"].contains(address) else {
            throw ToolingError(.invalidConfiguration, "The service listens on this machine's loopback alone - 127.0.0.1, ::1 - not \(address).")
        }
        return ServiceListener(socket: try StreamSocket.listen(on: address, port: port))
    }

    /// Serves every connection made to it, each as long as its client keeps it, until the task is cancelled.
    public func serve() async {
        let accepted = AsyncStream<StreamSocket> { continuation in
            let acceptor = Thread { [socket] in
                while let client = try? socket.accept() { continuation.yield(client) }
                continuation.finish()
            }
            acceptor.name = "stateui service"
            acceptor.start()
        }
        await withTaskCancellationHandler {
            await withDiscardingTaskGroup { group in
                for await client in accepted {
                    group.addTask { await Self.serve(client) }
                }
            }
        } onCancel: { [socket] in
            socket.close()
        }
    }

    /// One client's connection, served until it ends; the socket closed after.
    private static func serve(_ client: StreamSocket) async {
        let writer = SocketWriter(client)
        let connection = Connection(
            server: ToolingService.identity, apiVersions: Release.apiVersions, methods: ToolingService().methods,
            send: writer.write, diagnose: { line in try? FileHandle.standardError.write(contentsOf: Data((line + "\n").utf8)) },
            backlog: writer.backlog)
        Task {
            for await bytes in client.chunks() {
                guard await connection.receive(Data(bytes)) else { break }
            }
            await connection.end()
        }
        await connection.closed()
        await connection.end()
        writer.flush()
        client.close()
    }
}

/// A connected socket as one writer: each frame written whole, in the order given, the bytes given but not yet
/// written counted - what a client that stops reading leaves.
final class SocketWriter: Sendable {
    private let socket: StreamSocket
    private let queue = DispatchQueue(label: "stateui socket writer")
    private let unwritten = Mutex(0)

    init(_ socket: StreamSocket) {
        self.socket = socket
    }

    /// Writes `frame` after every frame given before it.
    @Sendable func write(_ frame: Data) {
        unwritten.withLock { $0 += frame.count }
        queue.async { [self] in
            try? socket.write(Array(frame))
            unwritten.withLock { $0 -= frame.count }
        }
    }

    /// The bytes given but not yet written.
    @Sendable func backlog() -> Int {
        unwritten.withLock { $0 }
    }

    /// Returns once every frame given is written.
    func flush() {
        queue.sync {}
    }
}

extension StreamSocket {
    /// What the other end writes, as it comes, read on a thread of its own; it ends as the connection does.
    func chunks() -> AsyncStream<[UInt8]> {
        AsyncStream { continuation in
            let reader = Thread { [self] in
                while let bytes = try? read(), !bytes.isEmpty { continuation.yield(bytes) }
                continuation.finish()
            }
            reader.name = "stateui socket reader"
            reader.start()
        }
    }
}
