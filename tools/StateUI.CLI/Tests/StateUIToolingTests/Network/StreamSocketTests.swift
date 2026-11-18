// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class StreamSocketTests: XCTestCase {
    /// A socket listening on a free port is reached by a connection: what each end writes the other reads, and once
    /// one end closes the other reads nothing more.
    func testAConnectionCarriesBytesBothWaysUntilItCloses() async throws {
        let listener = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { listener.close() }
        XCTAssertNotEqual(listener.port, 0)
        let accepted = Task.detached { try listener.accept() }
        let client = try StreamSocket.connect(to: "127.0.0.1", port: listener.port)
        let server = try await accepted.value
        try client.write(Array("Content-Length: 2\r\n\r\n{}".utf8))
        var heard: [UInt8] = []
        while heard.count < 23 { heard += try server.read() }
        XCTAssertEqual(String(decoding: heard, as: UTF8.self), "Content-Length: 2\r\n\r\n{}")
        try server.write(Array("ok".utf8))
        XCTAssertEqual(try client.read(), Array("ok".utf8))
        client.close()
        XCTAssertEqual(try server.read(), [])
        server.close()
    }

    /// A place no machine is named by is refused as a configuration, and a port nothing listens on as a failure to
    /// connect.
    func testWhatCannotBeReachedIsSaid() throws {
        XCTAssertThrowsError(try StreamSocket.connect(to: "no-such-machine.invalid", port: 7979)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
        }
        let free = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let port = free.port
        free.close()
        XCTAssertThrowsError(try StreamSocket.connect(to: "127.0.0.1", port: port)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .toolFailed)
        }
    }

    /// A socket closed takes no call after: its number, given back, may be another socket's, so a write through it
    /// never reaches that one's peer.
    func testAClosedSocketNeverReachesTheNumberItGaveBack() throws {
        let listening = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { listening.close() }
        let old = try StreamSocket.connect(to: "127.0.0.1", port: listening.port)
        let oldServed = try listening.accept()
        defer { oldServed.close() }
        let number = old.number
        old.close()
        let fresh = try StreamSocket.connect(to: "127.0.0.1", port: listening.port)
        defer { fresh.close() }
        let served = try listening.accept()
        defer { served.close() }
        guard fresh.number == number else { throw XCTSkip("the system gave the new socket another number") }
        _ = try? old.write(Array("stale".utf8))
        try fresh.write(Array("fresh".utf8))
        XCTAssertEqual(String(decoding: try served.read(), as: UTF8.self), "fresh")
    }

    /// An accept waiting on a listening socket, and a read waiting on a connected one, return once that socket is
    /// closed from another thread.
    func testAWaitingCallReturnsOnceItsSocketCloses() throws {
        func returns(_ call: @escaping @Sendable () -> Void, closing socket: StreamSocket) -> Bool {
            let done = DispatchSemaphore(value: 0)
            Thread { call(); done.signal() }.start()
            Thread.sleep(forTimeInterval: 0.2)
            socket.close()
            return done.wait(timeout: .now() + 5) == .success
        }
        let listening = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        XCTAssertTrue(returns({ _ = try? listening.accept() }, closing: listening), "accept")
        let other = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { other.close() }
        let peer = try StreamSocket.connect(to: "127.0.0.1", port: other.port)
        defer { peer.close() }
        let served = try other.accept()
        XCTAssertTrue(returns({ _ = try? served.read() }, closing: served), "read")
    }

    /// A listening socket closed while an accept waits on it keeps its number until that accept returns - one admitted
    /// may not yet have reached the system - and gives it back after.
    func testAListeningSocketKeepsItsNumberWhileAnAcceptWaits() throws {
        #if os(Windows)
        throw XCTSkip("a socket's number is a handle on Windows, which fcntl does not read")
        #else
        let listening = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let number = Int32(listening.number)
        let done = DispatchSemaphore(value: 0)
        Thread { _ = try? listening.accept(); done.signal() }.start()
        Thread.sleep(forTimeInterval: 0.2)
        listening.close()
        XCTAssertNotEqual(fcntl(number, F_GETFD), -1, "given back while its accept waits")
        XCTAssertEqual(done.wait(timeout: .now() + 5), .success, "the accept returned")
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(fcntl(number, F_GETFD), -1, "given back once its accept returned")
        #endif
    }
}
