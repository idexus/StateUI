// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class DebugRelayTests: XCTestCase {
    /// A relay carries a debugger's bytes to a port a run holds on the paired machine's loopback, and back; a port no
    /// run holds is refused, and so is a client whose token is not the pairing's.
    func testARelayCarriesBytesToAHeldPortAlone() async throws {
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("relay-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office", identity: String(repeating: "c3", count: 32))
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let office = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)

        // A server echoing what it is sent stands for an lldb-server.
        let echo = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { echo.close() }
        let echoing = Thread {
            while let peer = try? echo.accept() {
                Thread { while let bytes = try? peer.read(), !bytes.isEmpty, (try? peer.write(bytes)) != nil {}; peer.close() }.start()
            }
        }
        echoing.start()
        let relay = try DebugRelay.open(to: office, port: echo.port)
        defer { relay.close() }
        let packet = Array("$qSupported#37".utf8)

        let refused = try StreamSocket.connect(to: "127.0.0.1", port: relay.port)
        try refused.write(packet)
        XCTAssertEqual(try refused.read(), [], "a port no run holds")
        refused.close()

        let answered: [UInt8] = try await DebugPorts.holding(echo.port) {
            let debugger = try StreamSocket.connect(to: "127.0.0.1", port: relay.port)
            defer { debugger.close() }
            try debugger.write(packet)
            var read: [UInt8] = []
            while read.count < packet.count {
                let bytes = try debugger.read()
                if bytes.isEmpty { break }
                read += bytes
            }
            return read
        }
        XCTAssertEqual(answered, packet)

        var stranger = office
        stranger.token = String(repeating: "0", count: 64)
        try await DebugPorts.holding(echo.port) {
            XCTAssertThrowsError(try DebugRelay.granted(stranger, port: echo.port))
        }
    }

    /// A debug adapter's messages name sources as each side writes them: a path under this machine's folder goes there
    /// under the copy - in Windows' way of writing it - and a path of the copy comes back as this machine's; any
    /// other path, and every other field, stays.
    func testADebugAdaptersPathsAreEachSidesOwn() throws {
        let translation = PathTranslation(here: "/Users/me/StateUI", there: #"C:\Users\me\stateui-guest\abc\StateUI"#, windows: true)
        let request: JSONValue = .object([
            "command": .string("setBreakpoints"),
            "arguments": .object(["source": .object(["path": .string("/Users/me/StateUI/apps/Notes/Sources/MainPage.swift")]),
                                  "breakpoints": .array([.object(["line": .number(12)])])]),
        ])
        let sent = translation.translated(request, toward: .there)
        XCTAssertEqual(sent, .object([
            "command": .string("setBreakpoints"),
            "arguments": .object(["source": .object(["path": .string(#"C:\Users\me\stateui-guest\abc\StateUI\apps\Notes\Sources\MainPage.swift"#)]),
                                  "breakpoints": .array([.object(["line": .number(12)])])]),
        ]))
        let frame: JSONValue = .object(["source": .object(["path": .string(#"c:\users\me\stateui-guest\abc\StateUI\apps\Notes\Sources\MainPage.swift"#)])])
        XCTAssertEqual(translation.translated(frame, toward: .here),
                       .object(["source": .object(["path": .string("/Users/me/StateUI/apps/Notes/Sources/MainPage.swift")])]))
        let elsewhere: JSONValue = .object(["source": .object(["path": .string(#"C:\Windows\System32\ntdll.dll"#)])])
        XCTAssertEqual(translation.translated(elsewhere, toward: .here), elsewhere)
        let line = try ToolingJSON.encoder().encode(ToolingJSON.decoder().decode(JSONValue.self, from: Data(#"{"line":12,"id":3}"#.utf8)))
        XCTAssertEqual(String(decoding: line, as: UTF8.self), #"{"id":3,"line":12}"#, "a whole number stays one")
    }
}
