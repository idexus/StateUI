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
            capabilities: ServerCapabilities(
                methods: ToolingService().methods.names, notifications: ToolingService().methods.notifications),
            limits: .current)
        let info = ServerInfo(server: tool, apiVersions: Release.apiVersions, machine: Machine(system: "macos", architecture: "arm64"))
        let demo = "file:///Users/example/Projects/Demo"
        let operation = "op-6f2b9a1c-0d4e-4a8b-9f3c-1e2d3c4b5a69"
        var finished = OperationSnapshot(
            id: operation, kind: "project/create", requestToken: "5f0e3c2a-6c55-4b7a-9d1e-2a4c8b7f9e10",
            createdAt: "2026-11-13T12:00:00.000Z")
        finished.state = .succeeded
        finished.startedAt = "2026-11-13T12:00:00.001Z"
        finished.finishedAt = "2026-11-13T12:00:02.000Z"
        finished.lastSequence = 2
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
            Example(name: "toolchain-check", messages: [
                ("request", try request("5", "toolchain/check", NoParameters())),
                ("response", try response("5", ToolchainReport(findings: [
                    ToolFinding(
                        component: "Swift 6.4 or newer", neededBy: "every host", hosts: HostFamily.allCases,
                        found: "6.4 (/usr/bin/swift)", tooOld: nil, advice: "Install Swift 6.4 from https://www.swift.org/install."),
                    ToolFinding(
                        component: "the Android NDK r30 or newer", neededBy: "Android", hosts: [.android], found: nil,
                        tooOld: "29.0.1", advice: "Install it with Android Studio's SDK Manager."),
                ]))),
            ], answeredAsWritten: false),
            Example(name: "project-create", messages: [
                ("request", try request("6", "project/create", Mutation(
                    requestToken: "5f0e3c2a-6c55-4b7a-9d1e-2a4c8b7f9e10",
                    request: ApplicationRequest(name: "Notes", parentUri: demo + "/apps")))),
                ("response", try response("6", OperationHandle(operationId: operation, state: .queued))),
            ], answeredAsWritten: false),
            Example(name: "operation-event", messages: [
                ("notification", try JSONValue(encoding: OutgoingMessage.notification(
                    method: "operation/event",
                    params: try JSONValue(encoding: OperationEvent(
                        operationId: operation, sequence: 1, timestamp: "2026-11-13T12:00:00.000Z",
                        event: .state(.running)))))),
            ], answeredAsWritten: false),
            Example(name: "operation-get", messages: [
                ("request", try request("7", "operation/get", OperationReference(operationId: operation))),
                ("response", try response("7", finished)),
            ], answeredAsWritten: false),
            Example(name: "operation-cancel", messages: [
                ("request", try request("8", "operation/cancel", OperationReference(operationId: operation))),
                ("response", try response("8", CancelResult(accepted: false, state: .succeeded))),
            ], answeredAsWritten: false),
            Example(name: "releases-list", messages: [
                ("request", try request("9", "releases/list", ReleaseQuery(minimum: "0.8.0"))),
                ("response", try response("9", ReleaseList(repository: Release.repository, releases: ["0.8.5", "0.8.4", "0.8.0"]))),
            ], answeredAsWritten: false),
            Example(name: "workspace-create", messages: [
                ("request", try request("10", "workspace/create", Mutation(
                    requestToken: "0b6f2c8e-3d1a-4f5b-8c7e-9a2d4b6c8e10",
                    request: WorkspaceRequest(name: "Demo", parentUri: "file:///Users/example/Projects", release: "0.8.5",
                                              application: "Notes")))),
                ("response", try response("10", OperationHandle(operationId: operation, state: .queued))),
            ], answeredAsWritten: false),
            Example(name: "workspace-useLibrary", messages: [
                ("request", try request("11", "workspace/useLibrary", Mutation(
                    requestToken: "7c3e1a9b-5f2d-4e8c-a6b4-1d3f5a7c9e20",
                    request: LibraryRequest(workspaceUri: demo, checkoutUri: "file:///Users/example/StateUI")))),
                ("response", try response("11", OperationHandle(operationId: operation, state: .queued))),
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

    /// A mutation's request: its token beside its own parameters.
    private struct Mutation<Request: Encodable>: Encodable {
        var requestToken: String
        var request: Request

        func encode(to encoder: any Encoder) throws {
            try request.encode(to: encoder)
            var token = encoder.container(keyedBy: Key.self)
            try token.encode(requestToken, forKey: .requestToken)
        }

        private enum Key: String, CodingKey { case requestToken }
    }

    /// Every notification the service sends has its example.
    func testEveryNotificationHasItsExample() throws {
        let names = Set(try Self.examples().map(\.name))
        for notification in ToolingService().methods.notifications {
            XCTAssertTrue(names.contains(notification.replacingOccurrences(of: "/", with: "-")), "\(notification) has no example")
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
