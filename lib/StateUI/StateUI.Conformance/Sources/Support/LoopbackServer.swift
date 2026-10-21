// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIFoundation
import Synchronization
#if os(Windows)
import WinSDK
#endif

/// The HTTP server the request cases send to, on this machine's loopback, beside the UI thread, a thread a
/// connection: it answers a request with the status 201, `X-Method` naming the request's method, `X-Asked` saying
/// what the request's own `X-Asked` said, and the request's body (`HostDriver.served()`); a request for `/held` it
/// holds - five seconds, or until its client closes the connection, which it counts (`HostDriver.held()`).
final class LoopbackServer: Sendable {
    /// The server, started at its first use; nil where the platform opens no socket.
    static let shared: LoopbackServer? = LoopbackServer()

    /// Where it listens, its scheme included.
    let address: String

    /// The requests for `/held` that came, and those whose client closed the connection before the answer.
    static let heldStarted = Atomic<Int>(0)
    static let heldStopped = Atomic<Int>(0)

    private init?() {
        #if os(WASI)
        return nil
        #else
        #if os(Windows)
        var data = WSADATA()
        guard WSAStartup(0x0202, &data) == 0 else { return nil }
        #endif
        let listener = socket(AF_INET, Self.stream, 0)
        guard Self.isOpen(listener) else { return nil }
        var place = sockaddr_in()
        place.sin_family = .init(AF_INET)
        #if os(Windows)
        place.sin_addr.S_un.S_addr = UInt32(0x7F00_0001).bigEndian
        #else
        place.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
        #endif
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &place) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, length) == 0 && listen(listener, 8) == 0 && getsockname(listener, $0, &length) == 0
            }
        }
        guard bound else { return nil }
        address = "http://127.0.0.1:\(UInt16(bigEndian: place.sin_port))"
        Self.start(on: listener, Self.accepting)
        #endif
    }

    #if !os(WASI)
    #if os(Windows)
    private typealias Socket = SOCKET
    private static let stream = SOCK_STREAM
    private static func isOpen(_ socket: Socket) -> Bool { socket != INVALID_SOCKET }
    private static func shut(_ socket: Socket) { closesocket(socket) }
    private static func receive(_ socket: Socket, into buffer: UnsafeMutableRawBufferPointer) -> Int {
        Int(recv(socket, buffer.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(buffer.count), 0))
    }
    private static func send(_ socket: Socket, _ bytes: UnsafeRawBufferPointer) -> Int {
        Int(WinSDK.send(socket, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(bytes.count), 0))
    }
    /// Whether `socket` has something to read - its client's closing included - within `milliseconds`.
    private static func readable(_ socket: Socket, within milliseconds: Int32) -> Bool {
        var watched = WSAPOLLFD(fd: socket, events: Int16(POLLRDNORM), revents: 0)
        return WSAPoll(&watched, 1, milliseconds) > 0
    }
    #else
    private typealias Socket = Int32
    #if canImport(Glibc)
    private static let stream = Int32(SOCK_STREAM.rawValue)
    #else
    private static let stream = SOCK_STREAM
    #endif
    private static func isOpen(_ socket: Socket) -> Bool { socket >= 0 }
    private static func shut(_ socket: Socket) { close(socket) }
    private static func receive(_ socket: Socket, into buffer: UnsafeMutableRawBufferPointer) -> Int {
        recv(socket, buffer.baseAddress!, buffer.count, 0)
    }
    /// Sends `bytes` - a peer that went no longer ends the process with a signal.
    private static func send(_ socket: Socket, _ bytes: UnsafeRawBufferPointer) -> Int {
        #if canImport(Darwin)
        var on: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        return StateUIFoundation.send(socket, bytes.baseAddress!, bytes.count, 0)
        #else
        return StateUIFoundation.send(socket, bytes.baseAddress!, bytes.count, Int32(MSG_NOSIGNAL))
        #endif
    }
    /// Whether `socket` has something to read - its client's closing included - within `milliseconds`.
    private static func readable(_ socket: Socket, within milliseconds: Int32) -> Bool {
        var watched = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
        return poll(&watched, 1, milliseconds) > 0
    }
    #endif

    /// What a thread runs, handed its socket.
    private typealias Work = @convention(c) (UnsafeMutableRawPointer?) -> Void

    /// Accepts connections for as long as the process runs, each answered on a thread of its own.
    private static let accepting: Work = { argument in
        let listener = LoopbackServer.taken(argument)
        while true {
            let connection = accept(listener, nil, nil)
            guard LoopbackServer.isOpen(connection) else { continue }
            LoopbackServer.start(on: connection, LoopbackServer.answering)
        }
    }

    /// Answers one connection and closes it.
    private static let answering: Work = { argument in
        let connection = LoopbackServer.taken(argument)
        LoopbackServer.answer(connection)
        LoopbackServer.shut(connection)
    }

    /// Runs `work` on a thread of its own, handed `socket`.
    private static func start(on socket: Socket, _ work: Work) {
        let held = UnsafeMutablePointer<(Socket, Work)>.allocate(capacity: 1)
        held.initialize(to: (socket, work))
        #if os(Windows)
        _ = CreateThread(nil, 0, { argument in
            let (socket, work) = LoopbackServer.handed(argument)
            work(LoopbackServer.argument(of: socket))
            return 0
        }, held, 0, nil)
        #else
        #if canImport(Darwin)
        var thread: pthread_t?
        #else
        var thread = pthread_t()
        #endif
        pthread_create(&thread, nil, { argument in
            let (socket, work) = LoopbackServer.handed(argument)
            work(LoopbackServer.argument(of: socket))
            return nil
        }, held)
        #endif
    }

    /// The socket and the work a thread was handed, let go of.
    private static func handed(_ argument: UnsafeMutableRawPointer?) -> (Socket, Work) {
        let held = argument!.assumingMemoryBound(to: (Socket, Work).self)
        defer { held.deinitialize(count: 1); held.deallocate() }
        return held.pointee
    }

    /// `socket` as the argument of a thread's work, and back.
    private static func argument(of socket: Socket) -> UnsafeMutableRawPointer? {
        UnsafeMutableRawPointer(bitPattern: UInt(socket))
    }
    private static func taken(_ argument: UnsafeMutableRawPointer?) -> Socket {
        Socket(UInt(bitPattern: argument))
    }

    /// Reads one request from `connection` and answers it.
    private static func answer(_ connection: Socket) {
        var received: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 4096)
        var headerEnd: Int?
        var bodyLength = 0
        while true {
            if let end = headerEnd, received.count >= end + bodyLength { break }
            let count = chunk.withUnsafeMutableBytes { receive(connection, into: $0) }
            guard count > 0 else { return }
            received += chunk[0..<count]
            if headerEnd == nil, let end = Self.end(of: received) {
                headerEnd = end
                bodyLength = Int(header("content-length", in: received[..<end]) ?? "") ?? 0
            }
        }
        guard let end = headerEnd else { return }
        let head = received[..<end]
        let line = String(decoding: head.prefix { $0 != 13 }, as: UTF8.self).split(separator: " ")
        let method = line.first.map(String.init) ?? ""
        let path = line.count > 1 ? String(line[1]) : "/"
        if path.hasSuffix("/held") {
            heldStarted.add(1, ordering: .sequentiallyConsistent)
            // Nothing more comes on this connection: what reads now is its client closing it.
            var closed = false
            for _ in 0..<100 {
                guard !closed else { break }
                closed = readable(connection, within: 50)
                    && chunk.withUnsafeMutableBytes { receive(connection, into: $0) } <= 0
            }
            if closed {
                heldStopped.add(1, ordering: .sequentiallyConsistent)
                return
            }
        }
        let body = Array(received[end..<min(received.count, end + bodyLength)])
        let response = Array(("HTTP/1.1 201 Created\r\nX-Method: \(method)\r\n"
            + "X-Asked: \(header("x-asked", in: head) ?? "")\r\nContent-Type: text/plain\r\n"
            + "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n").utf8) + body
        var sent = 0
        while sent < response.count {
            let count = response[sent...].withUnsafeBytes { send(connection, $0) }
            guard count > 0 else { return }
            sent += count
        }
    }

    /// Where the headers end and the body begins: past the blank line.
    private static func end(of bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        for index in 0...(bytes.count - 4) where bytes[index..<index + 4].elementsEqual([13, 10, 13, 10]) {
            return index + 4
        }
        return nil
    }

    /// The value of the header `name`, in lowercase, among the request's lines.
    private static func header(_ name: String, in head: ArraySlice<UInt8>) -> String? {
        for line in String(decoding: head, as: UTF8.self).split(separator: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":"), line[..<colon].lowercased() == name else { continue }
            return String(line[line.index(after: colon)...].drop { $0 == " " })
        }
        return nil
    }
    #endif
}
