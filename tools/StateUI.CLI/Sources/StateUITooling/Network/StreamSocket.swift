// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(WinSDK)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import StateUIToolingProtocol
import Synchronization

/// A TCP socket of the system's own - BSD sockets on macOS and Linux, Winsock on Windows - listening or connected:
/// the road another machine's tool is reached by, one implementation on every system. Reads and writes block; a
/// caller gives each its own thread.
/// Design: docs/design/tooling/service.md#the-socket
public final class StreamSocket: Sendable {
    #if os(Windows)
    typealias Handle = SOCKET
    private static let invalid = INVALID_SOCKET
    #else
    typealias Handle = Int32
    private static let invalid: Int32 = -1
    #endif

    private let handle: Handle
    private let life = Mutex(Life())

    /// Whether the socket stands, the calls using its handle now, and whether the handle went back to the system - once
    /// it is closed and the last of them returned, so no call reaches a number the system gave another socket.
    private struct Life {
        var open = true
        var calls = 0
        var released = false
    }

    private init(_ handle: Handle) {
        self.handle = handle
    }

    /// The system's number of the socket.
    var number: Int { Int(handle) }

    /// A socket listening on `address` - `127.0.0.1`, `0.0.0.0`, a host's name - at `port`, any free one for 0.
    public static func listen(on address: String, port: UInt16) throws(ToolingError) -> StreamSocket {
        let socket = try open(address, port: port, passive: true) { handle, place in
            var yes: Int32 = 1
            #if os(Windows)
            _ = withUnsafeBytes(of: &yes) { setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, $0.baseAddress!.assumingMemoryBound(to: CChar.self), 4) }
            #else
            _ = setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            #endif
            return bind(handle, place.ai_addr, socklen_t(place.ai_addrlen)) == 0 && WinSDKOrPOSIX.listen(handle, 16) == 0
        }
        return socket
    }

    /// A socket connected to `address` at `port`.
    public static func connect(to address: String, port: UInt16) throws(ToolingError) -> StreamSocket {
        try open(address, port: port, passive: false) { handle, place in
            WinSDKOrPOSIX.connect(handle, place.ai_addr, socklen_t(place.ai_addrlen)) == 0
        }
    }

    /// The port it listens on or is connected from; 0 once it is closed.
    public var port: UInt16 {
        var storage = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        guard (holding { handle in
            withUnsafeMutablePointer(to: &storage) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(handle, $0, &length) }
            }
        }) != nil else { return 0 }
        let family = Int32(storage.ss_family)
        return withUnsafePointer(to: &storage) { stored in
            if family == AF_INET6 {
                return stored.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { UInt16(bigEndian: $0.pointee.sin6_port) }
            }
            return stored.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt16(bigEndian: $0.pointee.sin_port) }
        }
    }

    /// The next connection made to a listening socket; it waits for one.
    public func accept() throws(ToolingError) -> StreamSocket {
        try ready("accept")
        guard let accepted = holding({ WinSDKOrPOSIX.accept($0, nil, nil) }) else { throw Self.closed("accept") }
        guard accepted != Self.invalid else { throw Self.failure("accept") }
        Self.quietOnClose(accepted)
        return StreamSocket(accepted)
    }

    /// What the other end wrote next, at most `count` bytes; none once it closed.
    public func read(upTo count: Int = 65_536) throws(ToolingError) -> [UInt8] {
        #if os(Windows)
        // Winsock's shutdown wakes no recv waiting.
        try ready("read")
        #endif
        var buffer = [UInt8](repeating: 0, count: count)
        let read = holding { handle in
            buffer.withUnsafeMutableBytes { bytes in
                #if os(Windows)
                Int(recv(handle, bytes.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(count), 0))
                #else
                recv(handle, bytes.baseAddress!, count, 0)
                #endif
            }
        }
        guard let read else { throw Self.closed("read") }
        guard read >= 0 else { throw Self.failure("read") }
        return Array(buffer.prefix(read))
    }

    /// Writes all of `bytes`.
    public func write(_ bytes: [UInt8]) throws(ToolingError) {
        var sent = 0
        while sent < bytes.count {
            let wrote = holding { handle in
                bytes.withUnsafeBytes { all in
                    let rest = all.baseAddress! + sent
                    #if os(Windows)
                    return Int(send(handle, rest.assumingMemoryBound(to: CChar.self), Int32(bytes.count - sent), 0))
                    #elseif os(Linux)
                    return send(handle, rest, bytes.count - sent, Int32(MSG_NOSIGNAL))
                    #else
                    return send(handle, rest, bytes.count - sent, 0)
                    #endif
                }
            }
            guard let wrote else { throw Self.closed("write") }
            guard wrote > 0 else { throw Self.failure("write") }
            sent += wrote
        }
    }

    /// Ends both directions, once - a read or a write waiting on it returns, and no call starts after - and gives the
    /// socket back to the system as the last call on it returns.
    /// Design: docs/design/tooling/service.md#the-socket
    public func close() {
        let release = life.withLock { life -> Bool in
            guard life.open else { return false }
            life.open = false
            // Under the lock: no call returning can give the number back before it is shut.
            #if os(Windows)
            _ = shutdown(handle, Int32(SD_BOTH))
            #else
            _ = shutdown(handle, Int32(SHUT_RDWR))
            #endif
            guard life.calls == 0 else { return false }
            life.released = true
            return true
        }
        if release { Self.release(handle) }
    }

    /// Returns once the socket has something for `step` - a connection to accept, bytes to read, its end or an error the
    /// call then says - waiting a tenth of a second at a time, so a close ends the wait where a call waiting in the
    /// system would not return: an accept anywhere, a read on Windows.
    private func ready(_ step: String) throws(ToolingError) {
        while true {
            guard let polled = holding({ handle -> Int32 in
                #if os(Windows)
                var poll = WSAPOLLFD(fd: handle, events: Int16(POLLRDNORM), revents: 0)
                return WSAPoll(&poll, 1, 100)
                #else
                var poll = pollfd(fd: handle, events: Int16(POLLIN), revents: 0)
                return WinSDKOrPOSIX.poll(&poll, 1, 100)
                #endif
            }) else { throw Self.closed(step) }
            if polled != 0 { return }
        }
    }

    /// `call` given the handle while the socket stands, the handle held for it until it returns; nil once it is closed.
    func holding<Result>(_ call: (Handle) -> Result) -> Result? {
        guard life.withLock({ life in
            guard life.open else { return false }
            life.calls += 1
            return true
        }) else { return nil }
        defer {
            let release = life.withLock { life -> Bool in
                life.calls -= 1
                guard !life.open, life.calls == 0, !life.released else { return false }
                life.released = true
                return true
            }
            if release { Self.release(handle) }
        }
        return call(handle)
    }

    private static func release(_ handle: Handle) {
        #if os(Windows)
        _ = closesocket(handle)
        #else
        _ = WinSDKOrPOSIX.close(handle)
        #endif
    }

    /// A socket for the first of `address`'s places at `port` that `ready` - binding, or connecting - takes.
    private static func open(
        _ address: String, port: UInt16, passive: Bool, ready: (Handle, addrinfo) -> Bool
    ) throws(ToolingError) -> StreamSocket {
        startOnce()
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if os(Linux)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        hints.ai_flags = passive ? AI_PASSIVE : 0
        var found: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(address, String(port), &hints, &found) == 0, let first = found else {
            throw ToolingError(.invalidConfiguration, "\(address) names no place this machine reaches.")
        }
        defer { freeaddrinfo(first) }
        var place: UnsafeMutablePointer<addrinfo>? = first
        var code = 0
        while let each = place {
            let handle = WinSDKOrPOSIX.socket(each.pointee.ai_family, each.pointee.ai_socktype, each.pointee.ai_protocol)
            if handle != invalid {
                quietOnClose(handle)
                if ready(handle, each.pointee) { return StreamSocket(handle) }
                code = lastError()
                StreamSocket(handle).close()
            } else {
                code = lastError()
            }
            place = each.pointee.ai_next
        }
        throw failure(passive ? "listen on \(address):\(port)" : "connect to \(address):\(port)", code: code)
    }

    /// A write to a socket whose other end closed fails, not ends the process: on a Mac by the socket's own option.
    private static func quietOnClose(_ handle: Handle) {
        #if canImport(Darwin)
        var yes: Int32 = 1
        _ = setsockopt(handle, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }

    /// Winsock started, once in a process; nothing elsewhere.
    private static let started: Bool = {
        #if os(Windows)
        var data = WSADATA()
        return WSAStartup(0x0202, &data) == 0
        #else
        return true
        #endif
    }()

    private static func startOnce() {
        _ = started
    }

    /// The system's code of the socket call that failed last - read before anything else calls it.
    private static func lastError() -> Int {
        #if os(Windows)
        Int(WSAGetLastError())
        #else
        Int(errno)
        #endif
    }

    private static func closed(_ step: String) -> ToolingError {
        ToolingError(.toolFailed, "The socket could not \(step): it is closed.")
    }

    private static func failure(_ step: String, code: Int = lastError()) -> ToolingError {
        ToolingError(.toolFailed, "The socket could not \(step): error \(code).")
    }
}

/// The system's socket calls under names a method of the socket's own does not hide.
private enum WinSDKOrPOSIX {
    #if os(Windows)
    static func socket(_ family: Int32, _ type: Int32, _ proto: Int32) -> SOCKET { WinSDK.socket(family, type, proto) }
    static func listen(_ handle: SOCKET, _ backlog: Int32) -> Int32 { WinSDK.listen(handle, backlog) }
    static func accept(_ handle: SOCKET, _ address: UnsafeMutablePointer<sockaddr>?, _ length: UnsafeMutablePointer<Int32>?) -> SOCKET {
        WinSDK.accept(handle, address, length)
    }
    static func connect(_ handle: SOCKET, _ address: UnsafePointer<sockaddr>!, _ length: Int32) -> Int32 { WinSDK.connect(handle, address, length) }
    #else
    #if canImport(Glibc)
    static func socket(_ family: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Glibc.socket(family, type, proto) }
    static func listen(_ handle: Int32, _ backlog: Int32) -> Int32 { Glibc.listen(handle, backlog) }
    static func accept(_ handle: Int32, _ address: UnsafeMutablePointer<sockaddr>?, _ length: UnsafeMutablePointer<socklen_t>?) -> Int32 {
        Glibc.accept(handle, address, length)
    }
    static func connect(_ handle: Int32, _ address: UnsafePointer<sockaddr>!, _ length: socklen_t) -> Int32 { Glibc.connect(handle, address, length) }
    static func close(_ handle: Int32) -> Int32 { Glibc.close(handle) }
    static func poll(_ fds: UnsafeMutablePointer<pollfd>, _ count: nfds_t, _ timeout: Int32) -> Int32 { Glibc.poll(fds, count, timeout) }
    #else
    static func socket(_ family: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Darwin.socket(family, type, proto) }
    static func listen(_ handle: Int32, _ backlog: Int32) -> Int32 { Darwin.listen(handle, backlog) }
    static func accept(_ handle: Int32, _ address: UnsafeMutablePointer<sockaddr>?, _ length: UnsafeMutablePointer<socklen_t>?) -> Int32 {
        Darwin.accept(handle, address, length)
    }
    static func connect(_ handle: Int32, _ address: UnsafePointer<sockaddr>!, _ length: socklen_t) -> Int32 { Darwin.connect(handle, address, length) }
    static func close(_ handle: Int32) -> Int32 { Darwin.close(handle) }
    static func poll(_ fds: UnsafeMutablePointer<pollfd>, _ count: nfds_t, _ timeout: Int32) -> Int32 { Darwin.poll(fds, count, timeout) }
    #endif
    #endif
}
