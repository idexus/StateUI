// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import Foundation
import StateUIToolingProtocol
import Synchronization

/// The tool's service: clients connected over TCP, each served as `serve --stdio` serves one over standard streams -
/// the protocol's connection, the tool's methods - and admitted only paired (`ServicePairing`).
/// Design: docs/design/tooling/service.md#the-service-listening
public struct ServiceListener: Sendable {
    private let socket: StreamSocket
    private let pairing: ServicePairing

    /// The port it listens on.
    public var port: UInt16 { socket.port }

    /// A service listening on `address` at `port` - any free one for 0 - admitting the clients `pairing` keeps.
    public static func open(on address: String, port: UInt16, pairing: ServicePairing) throws(ToolingError) -> ServiceListener {
        ServiceListener(socket: try StreamSocket.listen(on: address, port: port), pairing: pairing)
    }

    /// The address and the port `listen` names: `address:port`, an IPv6 address within brackets.
    public static func place(_ listen: String) throws(ToolingError) -> (String, UInt16) {
        let bracketed = listen.hasPrefix("[")
        guard let colon = listen.lastIndex(of: ":"), let port = UInt16(listen[listen.index(after: colon)...]) else {
            throw ToolingError(.invalidConfiguration, "--listen is an address and a port, 127.0.0.1:7979 - not \(listen).")
        }
        var address = String(listen[..<colon])
        if bracketed, address.hasSuffix("]") { address = String(address.dropFirst().dropLast()) }
        return (address, port)
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
                    group.addTask { [pairing] in await Self.serve(client, pairing: pairing) }
                }
            }
        } onCancel: { [socket] in
            socket.close()
        }
    }

    /// One client's connection, served until it ends - or, a relay granted, carried as bytes to the port it names
    /// until either end closes; the socket closed after.
    private static func serve(_ client: StreamSocket, pairing: ServicePairing) async {
        let writer = SocketWriter(client)
        let relayed = Mutex<UInt16?>(nil)
        let connection = Connection(
            server: ToolingService.identity, apiVersions: Release.apiVersions, methods: ToolingService().methods,
            send: writer.write, diagnose: { line in try? FileHandle.standardError.write(contentsOf: Data((line + "\n").utf8)) },
            backlog: writer.backlog, admission: pairing.admission(relaying: { port in relayed.withLock { $0 = port } }))
        Task {
            var chunks = client.chunks().makeAsyncIterator()
            while let bytes = await chunks.next() {
                guard await connection.receive(Data(bytes)) else { break }
                if let port = relayed.withLock({ $0 }) {
                    writer.flush()
                    await Self.carry(client, rest: &chunks, to: port)
                    break
                }
            }
            await connection.end()
        }
        await connection.closed()
        await connection.end()
        Self.end(client, writer: writer, lost: await connection.lost)
    }

    /// Ends `client`'s connection: what it was sent written before its socket closes - but a `lost` client reads
    /// nothing, so its socket shuts first and the frames still waiting fail rather than wait for it.
    static func end(_ client: StreamSocket, writer: SocketWriter, lost: Bool) {
        if lost { client.close() }
        writer.flush()
        client.close()
    }

    /// The rest of `client`'s bytes carried to `port` of the loopback, and that port's back, until either end closes.
    /// Design: docs/design/tooling/service.md#a-debugger-relayed
    private static func carry(_ client: StreamSocket, rest chunks: inout AsyncStream<[UInt8]>.Iterator, to port: UInt16) async {
        let target: StreamSocket
        do {
            target = try StreamSocket.connect(to: "127.0.0.1", port: port)
        } catch {
            try? FileHandle.standardError.write(contentsOf: Data("stateui: the relay to port \(port) found no one listening: \(error)\n".utf8))
            return
        }
        let back = Thread {
            while let bytes = try? target.read(), !bytes.isEmpty, (try? client.write(bytes)) != nil {}
            client.close()
        }
        back.name = "stateui relay"
        back.start()
        while let bytes = await chunks.next(), (try? target.write(bytes)) != nil {}
        target.close()
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
