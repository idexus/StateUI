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
    /// The methods the connection answers, its operations among them.
    let methods: Methods
    private let transcript = Transcript()
    private let read = Mutex(0)

    init(
        apiVersions: [APIVersionRange] = [APIVersionRange(major: 1, minMinor: 0, maxMinor: 2)],
        lostAfter: Duration = .seconds(30),
        stopLimit: Duration = .seconds(10)
    ) {
        let backlog = Backlog()
        self.backlogSource = backlog
        let (service, transcript) = (FakeService(), transcript)
        let methods = service.methods
        self.service = service
        self.methods = methods
        connection = Connection(
            server: ToolIdentity(name: "stateui", version: "0.0.0"),
            apiVersions: apiVersions,
            methods: methods,
            send: { frame in transcript.written.withLock { $0 += Array(frame) } },
            diagnose: { line in transcript.diagnostics.withLock { $0.append(line) } },
            backlog: { backlog.bytes.withLock { $0 } },
            lostAfter: lostAfter,
            stopLimit: stopLimit
        )
    }

    private let backlogSource: Backlog

    /// Says the client leaves `bytes` unread.
    func leaveUnread(_ bytes: Int) {
        backlogSource.bytes.withLock { $0 = bytes }
    }

    /// The messages written until `done` holds of them all, waited for up to five seconds.
    func messages(until done: ([JSONValue]) -> Bool) async throws -> [JSONValue] {
        var gathered: [JSONValue] = []
        let deadline = ContinuousClock.now + .seconds(5)
        while !done(gathered), ContinuousClock.now < deadline {
            gathered += try unread()
            if !done(gathered) { try await Task.sleep(for: .milliseconds(5)) }
        }
        return gathered
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

/// The bytes a test says its client leaves unread.
final class Backlog: Sendable {
    let bytes = Mutex(0)
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
