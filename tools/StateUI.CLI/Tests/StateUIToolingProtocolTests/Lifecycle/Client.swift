// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import Synchronization
import XCTest

/// A client of a connection to a fake service, reading what the connection writes.
final class Client: Sendable {
    let connection: Connection
    let service: FakeService
    private let transcript = Transcript()
    private let read = Mutex(0)

    init(apiVersions: [APIVersionRange] = [APIVersionRange(major: 1, minMinor: 0, maxMinor: 2)]) {
        let (service, transcript) = (FakeService(), transcript)
        self.service = service
        connection = Connection(
            server: ToolIdentity(name: "stateui", version: "0.0.0"),
            apiVersions: apiVersions,
            methods: service.methods,
            send: { frame in transcript.written.withLock { $0 += Array(frame) } },
            diagnose: { line in transcript.diagnostics.withLock { $0.append(line) } }
        )
    }

    /// Sends `json` as one frame; whether the connection goes on.
    @discardableResult
    func send(_ json: String) async -> Bool {
        await connection.receive(Data(("Content-Length: \(json.utf8.count)\r\n\r\n" + json).utf8))
    }

    /// Sends the request `method` with `params` as id `id`.
    @discardableResult
    func request(_ id: String, _ method: String, _ params: String = "{}") async -> Bool {
        await send(#"{"jsonrpc":"2.0","id":"\#(id)","method":"\#(method)","params":\#(params)}"#)
    }

    /// Sends the notification `method`.
    func notify(_ method: String) async {
        await send(#"{"jsonrpc":"2.0","method":"\#(method)"}"#)
    }

    /// Opens the connection: `initialize`, then `initialized`.
    func open() async throws {
        await request("open", "initialize", Self.initialize)
        await notify("initialized")
        _ = try await messages()
    }

    static let initialize = #"{"apiVersions":[{"major":1,"minMinor":0,"maxMinor":0}],"#
        + #""client":{"name":"test","version":"1"},"workspaceUri":"file:///w"}"#

    /// The messages written since the last call, once every request accepted is answered.
    func messages() async throws -> [JSONValue] {
        await connection.settle()
        return try unread()
    }

    /// The next `count` messages written, waited for up to five seconds, while other requests stay unanswered.
    func messages(count: Int) async throws -> [JSONValue] {
        var gathered: [JSONValue] = []
        let deadline = ContinuousClock.now + .seconds(5)
        while gathered.count < count, ContinuousClock.now < deadline {
            gathered += try unread()
            if gathered.count < count { try await Task.sleep(for: .milliseconds(10)) }
        }
        return gathered
    }

    private func unread() throws -> [JSONValue] {
        var reader = FrameReader()
        let bodies = try reader.take(transcript.written.withLock { $0 })
        let all = try bodies.map { try ToolingJSON.decoder().decode(JSONValue.self, from: $0) }
        let new = read.withLock { seen in defer { seen = all.count }; return Array(all.dropFirst(seen)) }
        return new
    }

    /// The diagnostics written so far.
    var diagnosed: [String] { transcript.diagnostics.withLock { $0 } }
}

/// What a connection wrote: its frames' bytes and its diagnostics.
final class Transcript: Sendable {
    let written = Mutex<[UInt8]>([])
    let diagnostics = Mutex<[String]>([])
}

extension JSONValue {
    /// The member `key` of an object.
    subscript(_ key: String) -> JSONValue? {
        if case .object(let object) = self { object[key] } else { nil }
    }
}
