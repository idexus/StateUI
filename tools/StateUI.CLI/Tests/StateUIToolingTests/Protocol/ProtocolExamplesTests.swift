// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import StateUITooling
import Synchronization
import XCTest

/// The recorded example messages: one exchange a method, one message a notification, each written from the
/// Swift types and true of the service - what an editor's client is held to.
final class ProtocolExamplesTests: XCTestCase {
    private struct Example {
        var name: String
        var messages: [(role: String, message: JSONValue)]
        /// Whether the service answers it as written; an answer of this machine's files is held to its type alone.
        var answeredAsWritten = true
    }

    private static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("exports/protocol")

    private static let tool = ToolIdentity(name: "stateui", version: "1.0.0")

    private static func request(_ id: String, _ method: String, _ params: some Encodable) throws -> JSONValue {
        .object([
            "jsonrpc": .string("2.0"), "id": .string(id), "method": .string(method),
            "params": try JSONValue(encoding: params),
        ])
    }

    private static func response(_ id: String, _ result: some Encodable) throws -> JSONValue {
        try JSONValue(encoding: OutgoingMessage.response(id: .string(id), outcome: .result(JSONValue(encoding: result))))
    }

    private static func notification(_ method: String) -> JSONValue {
        .object(["jsonrpc": .string("2.0"), "method": .string(method)])
    }

    /// The examples, in the order a connection meets them.
    private static func examples() throws -> [Example] {
        let initialize = InitializeParameters(
            apiVersions: Release.apiVersions,
            client: ToolIdentity(name: "stateui-vscode", version: "1.0.0"),
            workspaceUri: "file:///Users/example/Projects/Demo")
        let initialized = InitializeResult(
            apiVersion: Release.newestAPIVersion,
            serverInstanceId: "00000000-0000-0000-0000-000000000000",
            server: tool,
            workspace: Workspace(uri: initialize.workspaceUri),
            capabilities: ServerCapabilities(methods: ToolingService().methods.names, notifications: []),
            limits: .current)
        let info = ServerInfo(server: tool, apiVersions: Release.apiVersions, machine: Machine(system: "macos", architecture: "arm64"))
        let demo = "file:///Users/example/Projects/Demo"
        let project = Project(
            rootUri: demo,
            applications: [Application(
                id: "apps/Notes", name: "Notes", packageUri: demo + "/apps/Notes", declaredHosts: [.appkit, .uikit],
                products: ["NotesUI"], testSuites: ["NotesTests"], libraryUri: demo + "/StateUI")],
            libraries: [Library(
                rootUri: demo + "/StateUI", release: "1.0.0", revision: "0123456789abcdef0123456789abcdef01234567",
                dirty: false)])
        return [
            Example(name: "initialize", messages: [
                ("request", try request("1", "initialize", initialize)), ("response", try response("1", initialized)),
            ]),
            Example(name: "initialized", messages: [("notification", notification("initialized"))]),
            Example(name: "server-info", messages: [
                ("request", try request("2", "server/info", NoParameters())), ("response", try response("2", info)),
            ]),
            Example(name: "project-describe", messages: [
                ("request", try request("4", "project/describe", ProjectReference(projectUri: demo))),
                ("response", try response("4", project)),
            ], answeredAsWritten: false),
            Example(name: "shutdown", messages: [
                ("request", .object(["jsonrpc": .string("2.0"), "id": .string("3"), "method": .string("shutdown")])),
                ("response", try JSONValue(encoding: OutgoingMessage.response(id: .string("3"), outcome: .result(.null)))),
            ]),
            Example(name: "exit", messages: [("notification", notification("exit"))]),
        ]
    }

    private static func file(_ example: Example) throws -> Data {
        let object = JSONValue.object(Dictionary(uniqueKeysWithValues: example.messages.map { ($0.role, $0.message) }))
        return try ToolingJSON.encoder(pretty: true).encode(object) + Data("\n".utf8)
    }

    /// The recorded files are the examples the Swift types write - `STATEUI_UPDATE_EXPORTS=1` records them - and
    /// no file stands for an example that is not.
    func testTheRecordedExamplesAreTheSwiftTypes() throws {
        let examples = try Self.examples()
        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try? FileManager.default.removeItem(at: Self.directory)
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            for example in examples {
                try Self.file(example).write(to: Self.directory.appendingPathComponent(example.name + ".json"))
            }
        }
        let recorded = try FileManager.default.contentsOfDirectory(atPath: Self.directory.path).sorted()
        XCTAssertEqual(recorded, examples.map { $0.name + ".json" }.sorted(), "record with STATEUI_UPDATE_EXPORTS=1")
        for example in examples {
            let file = Self.directory.appendingPathComponent(example.name + ".json")
            XCTAssertEqual(try? Data(contentsOf: file), try Self.file(example), "\(file.lastPathComponent) differs")
        }
    }

    /// Every method the service answers has its example.
    func testEveryMethodHasItsExample() throws {
        let names = Set(try Self.examples().map(\.name))
        for method in ToolingService().methods.names + ["initialize", "shutdown"] {
            XCTAssertTrue(names.contains(method.replacingOccurrences(of: "/", with: "-")), "\(method) has no example")
        }
    }

    /// The examples' requests, sent to the service in their order, are answered as their responses say - the
    /// service's instance, identity and machine aside.
    func testTheServiceAnswersAsTheExamplesSay() async throws {
        let written = Written()
        let connection = Connection(
            server: Self.tool, apiVersions: Release.apiVersions, methods: ToolingService().methods,
            send: { frame in written.bytes.withLock { $0 += Array(frame) } }, diagnose: { _ in })
        var expected: [JSONValue] = []
        for example in try Self.examples() where example.answeredAsWritten {
            for (role, message) in example.messages {
                if role == "response" { expected.append(message); continue }
                let body = try ToolingJSON.encoder().encode(message)
                _ = await connection.receive(Data("Content-Length: \(body.count)\r\n\r\n".utf8) + body)
                await connection.settle()
            }
        }
        var reader = FrameReader()
        let answers = try reader.take(written.bytes.withLock { $0 }).map {
            Self.withoutTheServer(try ToolingJSON.decoder().decode(JSONValue.self, from: $0))
        }
        XCTAssertEqual(answers, expected.map(Self.withoutTheServer))
    }

    /// `value` without what differs between services: the instance, the identity and the machine.
    private static func withoutTheServer(_ value: JSONValue) -> JSONValue {
        guard case .object(var object) = value else { return value }
        for key in ["serverInstanceId", "server", "machine"] where object[key] != nil { object[key] = .null }
        return .object(object.mapValues(withoutTheServer))
    }
}

private final class Written: Sendable {
    let bytes = Mutex<[UInt8]>([])
}
