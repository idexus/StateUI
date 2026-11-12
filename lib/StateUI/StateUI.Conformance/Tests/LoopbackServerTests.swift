// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIConformance
import StateUIFoundation
import XCTest
#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#endif

/// The request cases' server answers connection after connection, each on a thread of its own, keeping nothing of
/// one once it is answered.
final class LoopbackServerTests: XCTestCase {
    /// A hundred requests answered leave the process holding no more than ten did: a thread answering one gives back
    /// what it took - its stack, its handle - as it ends.
    func testAnsweredRequestsLeaveNothingHeld() throws {
        let server = try XCTUnwrap(LoopbackServer.shared, "this platform opens no socket")
        let port = try XCTUnwrap(server.address.split(separator: ":").last.flatMap { UInt16($0) })
        for _ in 0..<10 { try Self.ask(port) }
        Self.waitForThreadsToEnd()
        let before = try XCTUnwrap(Self.held())

        for _ in 0..<100 { try Self.ask(port) }
        Self.waitForThreadsToEnd()

        XCTAssertLessThan(try XCTUnwrap(Self.held()) - before, 20, "each answered request left something held")
    }

    /// Asks the server for `/` on its own connection and reads the answer to its end.
    private static func ask(_ port: UInt16) throws {
        let connection = socket(AF_INET, Self.stream, 0)
        defer { Self.close(connection) }
        var place = sockaddr_in()
        place.sin_family = .init(AF_INET)
        place.sin_port = port.bigEndian
        #if os(Windows)
        place.sin_addr.S_un.S_addr = UInt32(0x7F00_0001).bigEndian
        #else
        place.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
        #endif
        let connected = withUnsafePointer(to: &place) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(connection, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard connected else { throw POSIXFailure(what: "connect") }
        let request = Array("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8)
        _ = request.withUnsafeBytes { Self.sent($0, on: connection) }
        var chunk = [UInt8](repeating: 0, count: 4096)
        while chunk.withUnsafeMutableBytes({ Self.received(into: $0, on: connection) }) > 0 {}
    }

    /// The server's threads close the connection before they end: a moment for the last to end.
    private static func waitForThreadsToEnd() {
        #if os(Windows)
        Sleep(200)
        #else
        usleep(200_000)
        #endif
    }

    /// What the process holds that a thread takes: its virtual memory regions, its open handles; nil for none read.
    private static func held() -> Int? {
        #if canImport(Darwin)
        var (address, regions): (mach_vm_address_t, Int) = (0, 0)
        while true {
            var size: mach_vm_size_t = 0
            var info = vm_region_basic_info_data_64_t()
            var count = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var object: mach_port_t = 0
            let read = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: Int32.self, capacity: Int(count)) {
                    mach_vm_region(mach_task_self_, &address, &size, VM_REGION_BASIC_INFO_64, $0, &count, &object)
                }
            }
            guard read == KERN_SUCCESS else { break }
            regions += 1
            address += size
        }
        return regions
        #elseif os(Windows)
        var count: DWORD = 0
        return GetProcessHandleCount(GetCurrentProcess(), &count) ? Int(count) : nil
        #else
        return (try? String(contentsOfFile: "/proc/self/maps", encoding: .utf8))?.split(separator: "\n").count
        #endif
    }

    #if os(Windows)
    private static let stream = SOCK_STREAM
    private static func close(_ socket: SOCKET) { closesocket(socket) }
    private static func sent(_ bytes: UnsafeRawBufferPointer, on socket: SOCKET) -> Int {
        Int(send(socket, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(bytes.count), 0))
    }
    private static func received(into bytes: UnsafeMutableRawBufferPointer, on socket: SOCKET) -> Int {
        Int(recv(socket, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(bytes.count), 0))
    }
    #else
    #if canImport(Glibc)
    private static let stream = Int32(SOCK_STREAM.rawValue)
    private static func close(_ socket: Int32) { _ = StateUIFoundation.close(socket) }
    #else
    private static let stream = SOCK_STREAM
    private static func close(_ socket: Int32) { _ = Darwin.close(socket) }
    #endif
    private static func sent(_ bytes: UnsafeRawBufferPointer, on socket: Int32) -> Int {
        send(socket, bytes.baseAddress, bytes.count, 0)
    }
    private static func received(into bytes: UnsafeMutableRawBufferPointer, on socket: Int32) -> Int {
        recv(socket, bytes.baseAddress, bytes.count, 0)
    }
    #endif
}

/// A call to the system that failed.
private struct POSIXFailure: Error {
    let what: String
}
