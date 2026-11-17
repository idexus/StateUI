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

    private init(_ handle: Handle) {
        self.handle = handle
    }

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

    /// The port it listens on or is connected from.
    public var port: UInt16 {
        var storage = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        _ = withUnsafeMutablePointer(to: &storage) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(handle, $0, &length) }
        }
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
        let accepted = WinSDKOrPOSIX.accept(handle, nil, nil)
        guard accepted != Self.invalid else { throw Self.failure("accept") }
        Self.quietOnClose(accepted)
        return StreamSocket(accepted)
    }

    /// What the other end wrote next, at most `count` bytes; none once it closed.
    public func read(upTo count: Int = 65_536) throws(ToolingError) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        let read = buffer.withUnsafeMutableBytes { bytes in
            #if os(Windows)
            Int(recv(handle, bytes.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(count), 0))
            #else
            recv(handle, bytes.baseAddress!, count, 0)
            #endif
        }
        guard read >= 0 else { throw Self.failure("read") }
        return Array(buffer.prefix(read))
    }

    /// Writes all of `bytes`.
    public func write(_ bytes: [UInt8]) throws(ToolingError) {
        var sent = 0
        while sent < bytes.count {
            let wrote = bytes.withUnsafeBytes { all in
                let rest = all.baseAddress! + sent
                #if os(Windows)
                return Int(send(handle, rest.assumingMemoryBound(to: CChar.self), Int32(bytes.count - sent), 0))
                #elseif os(Linux)
                return send(handle, rest, bytes.count - sent, Int32(MSG_NOSIGNAL))
                #else
                return send(handle, rest, bytes.count - sent, 0)
                #endif
            }
            guard wrote > 0 else { throw Self.failure("write") }
            sent += wrote
        }
    }

    /// Ends both directions and gives the socket back: a read waiting on it returns.
    public func close() {
        #if os(Windows)
        _ = shutdown(handle, Int32(SD_BOTH))
        _ = closesocket(handle)
        #else
        _ = shutdown(handle, Int32(SHUT_RDWR))
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
        while let each = place {
            let handle = WinSDKOrPOSIX.socket(each.pointee.ai_family, each.pointee.ai_socktype, each.pointee.ai_protocol)
            if handle != invalid {
                quietOnClose(handle)
                if ready(handle, each.pointee) { return StreamSocket(handle) }
                StreamSocket(handle).close()
            }
            place = each.pointee.ai_next
        }
        throw failure(passive ? "listen on \(address):\(port)" : "connect to \(address):\(port)")
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

    private static func failure(_ step: String) -> ToolingError {
        #if os(Windows)
        let code = Int(WSAGetLastError())
        #else
        let code = Int(errno)
        #endif
        return ToolingError(.toolFailed, "The socket could not \(step): error \(code).")
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
    #else
    static func socket(_ family: Int32, _ type: Int32, _ proto: Int32) -> Int32 { Darwin.socket(family, type, proto) }
    static func listen(_ handle: Int32, _ backlog: Int32) -> Int32 { Darwin.listen(handle, backlog) }
    static func accept(_ handle: Int32, _ address: UnsafeMutablePointer<sockaddr>?, _ length: UnsafeMutablePointer<socklen_t>?) -> Int32 {
        Darwin.accept(handle, address, length)
    }
    static func connect(_ handle: Int32, _ address: UnsafePointer<sockaddr>!, _ length: socklen_t) -> Int32 { Darwin.connect(handle, address, length) }
    static func close(_ handle: Int32) -> Int32 { Darwin.close(handle) }
    #endif
    #endif
}
