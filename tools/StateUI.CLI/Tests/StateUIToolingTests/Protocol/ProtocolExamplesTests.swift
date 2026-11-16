// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import StateUITooling
import Synchronization
import XCTest

/// The recorded example messages: one exchange a method, one message a notification, each written from the
/// Swift types and true of the service - what an editor's client is held to. A method starting an operation records
/// the operation's result too, as `operation/get` gives it once the operation succeeded.
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
                id: "apps/Notes", name: "Notes", identifier: "com.example.notes", version: "1.0.0", build: 1,
                packageUri: demo + "/apps/Notes", declaredHosts: [.appkit, .uikit],
                products: ["NotesUI"], testSuites: ["NotesTests"], libraryUri: demo + "/StateUI")],
            libraries: [Library(
                rootUri: demo + "/StateUI", release: "1.0.0", revision: "0123456789abcdef0123456789abcdef01234567",
                dirty: false)])
        let creation = ProjectCreation(
            project: project, createdUris: [demo + "/apps/Notes", demo + "/stateui-workspace.json"])
        finished.result = try JSONValue(encoding: creation)
        let made = WorkspaceChange(
            workspaceUri: demo, library: "StateUI",
            changedUris: [demo + "/stateui-workspace.json", demo + "/StateUI", demo + "/Notes"])
        let used = LibraryChange(
            projectUri: demo, library: "../../StateUI",
            changedUris: [demo + "/stateui-workspace.json", demo + "/Notes/Package.swift"])
        let artifact = demo + "/apps/Notes/.build/stateui/artifacts/appkit-arm64-67f9bfc089c6-debug"
        let built = BuildResult(
            application: "Notes", host: .appkit, configuration: .debug, architecture: .arm64, folderUri: artifact,
            programUri: artifact + "/NotesAppKit.app/Contents/MacOS/NotesAppKit", bundleUri: artifact + "/NotesAppKit.app")
        let simulator = Destination(
            id: "C8992893-1166-4CDF-AF44-2169C94EE53B", udid: "C8992893-1166-4CDF-AF44-2169C94EE53B", name: "iPhone 18 Pro",
            kind: .simulator, version: "27.0", booted: true)
        let ran = demo + "/apps/Notes/.build/stateui/artifacts/uikit-arm64-b0d562ff4ef0-debug"
        let launched = LaunchedApplication(
            build: BuildResult(
                application: "Notes", host: .uikit, configuration: .debug, architecture: .arm64, folderUri: ran,
                programUri: ran + "/NotesUIKit.app/NotesUIKit", bundleUri: ran + "/NotesUIKit.app", destination: simulator),
            process: 33316, held: true)
        let laid = demo + "/artifacts/Notes/UIKit"
        let packaged = BuildResult(
            application: "Notes", host: .uikit, configuration: .release, architecture: .arm64, folderUri: laid,
            programUri: laid + "/NotesUIKit.app/NotesUIKit", bundleUri: laid + "/NotesUIKit.app",
            destination: Destination(
                id: "0B05862F-1427-5E93-AFC2-5FEAA82B99FB", udid: "00008132-001808DC3C03001C", name: "Example iPad",
                kind: .device, version: "27.0", connection: "USB"))
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
            Example(name: "settings-get", messages: [
                ("request", try request("4", "settings/get", SettingsRequest(projectUri: demo))),
                ("response", try response("4", Settings(
                    workspaceUri: demo, startup: "Notes", applicationUri: demo + "/apps/Notes", host: .uikit,
                    devices: ["android": "emulator-5554", "uikit": "iPhone 18 Pro"]))),
            ], answeredAsWritten: false),
            Example(name: "settings-set", messages: [
                ("request", try request("12", "settings/set", Mutation(
                    requestToken: "2b8e4f6a-9c1d-4e3f-8a5b-7d9c1e3f5a7b",
                    request: SettingsChange(projectUri: demo, host: .uikit, devices: ["uikit": "iPhone 18 Pro"])))),
                ("response", try response("12", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: Settings(
                    workspaceUri: demo, startup: "Notes", applicationUri: demo + "/apps/Notes", host: .uikit,
                    devices: ["uikit": "iPhone 18 Pro"]))),
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
                ("result", try JSONValue(encoding: creation)),
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
            Example(name: "application-build", messages: [
                ("request", try request("13", "application/build", Mutation(
                    requestToken: "2a9c4e6b-8d1f-4a3c-b5e7-0f9d2c4a6b80",
                    request: BuildRequest(projectUri: demo + "/apps/Notes", host: .appkit)))),
                ("response", try response("13", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: built)),
            ], answeredAsWritten: false),
            Example(name: "application-package", messages: [
                ("request", try request("14", "application/package", Mutation(
                    requestToken: "4c1e8a2d-6b3f-4e5a-9c7d-1b3e5f7a9c20",
                    request: BuildRequest(projectUri: demo + "/apps/Notes", host: .uikit, configuration: .release,
                                          device: "Example iPad", outputUri: demo + "/artifacts/Notes/UIKit")))),
                ("response", try response("14", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: packaged)),
            ], answeredAsWritten: false),
            Example(name: "application-run", messages: [
                ("request", try request("16", "application/run", Mutation(
                    requestToken: "9d2b4f6a-8c1e-4a3b-b5d7-2e4f6a8c0b30",
                    request: RunRequest(build: BuildRequest(projectUri: demo + "/apps/Notes", host: .uikit, device: "iPhone 18 Pro"),
                                        debugger: true)))),
                ("response", try response("16", OperationHandle(operationId: operation, state: .queued))),
                ("notification", try JSONValue(encoding: OutgoingMessage.notification(
                    method: "operation/event",
                    params: try JSONValue(encoding: OperationEvent(
                        operationId: operation, sequence: 9, timestamp: "2026-11-14T12:00:00.000Z",
                        event: .started(launched)))))),
                ("result", try JSONValue(encoding: RunResult(launched: launched, exitStatus: nil))),
            ], answeredAsWritten: false),
            Example(name: "application-install", messages: [
                ("request", try request("17", "application/install", Mutation(
                    requestToken: "2e6a8c0b-4d1f-4b3e-9a5c-7e9b1d3f5a40",
                    request: InstallRequest(artifactUri: demo + "/apps/Notes/.build/stateui/artifacts/gtk-arm64-1b2c3d4e5f60-debug")))),
                ("response", try response("17", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: InstallResult(
                    artifactUri: demo + "/apps/Notes/.build/stateui/artifacts/gtk-arm64-1b2c3d4e5f60-debug",
                    writtenUris: ["file:///home/example/.local/share/applications/com.stateui.notes.desktop",
                                  "file:///home/example/.local/share/icons/hicolor/scalable/apps/com.stateui.notes.svg"]))),
            ], answeredAsWritten: false),
            Example(name: "name-check", messages: [
                ("request", try request("12", "name/check", NameCheck(kind: .application, name: "My-App", parentUri: demo + "/apps"))),
                ("response", try response("12", NameVerdict(
                    problem: "'My-App' cannot name an application: letters and digits only, starting with a letter."))),
            ]),
            Example(name: "devices-list", messages: [
                ("request", try request("15", "devices/list", DestinationQuery(host: .uikit))),
                ("response", try response("15", DestinationList(host: .uikit, destinations: [
                    Destination(
                        id: "0B05862F-1427-5E93-AFC2-5FEAA82B99FB", udid: "00008132-001808DC3C03001C", name: "Example iPad",
                        kind: .device, version: "27.0", connection: "USB"),
                    Destination(
                        id: "C8992893-1166-4CDF-AF44-2169C94EE53B", udid: "C8992893-1166-4CDF-AF44-2169C94EE53B",
                        name: "iPhone 18 Pro", kind: .simulator, version: "27.0", booted: true),
                ]))),
            ], answeredAsWritten: false),
            Example(name: "tests-discover", messages: [
                ("request", try request("18", "tests/discover", TestDiscoveryQuery(host: .appkit))),
                ("response", try response("18", TestSuiteList(host: .appkit, suites: [
                    TestSuiteDescription(id: "Demo", detail: "swift test", kind: .package, packageUri: demo),
                    TestSuiteDescription(id: "apps/Notes", detail: "swift test as an AppKit build, on .build/appkit", kind: .package,
                                         packageUri: demo + "/apps/Notes", host: .appkit),
                ]))),
            ], answeredAsWritten: false),
            Example(name: "tests-run", messages: [
                ("request", try request("19", "tests/run", Mutation(
                    requestToken: "7c1d9e3b-5a2f-4c6d-8e0b-1f3a5c7e9b20",
                    request: TestRunRequest(suite: "apps/Notes", host: .appkit)))),
                ("response", try response("19", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: SuiteResult(suite: "apps/Notes", phases: [SuiteResult.Phase(name: "tests", passed: true)]))),
            ], answeredAsWritten: false),
            Example(name: "repository-conformance", messages: [
                ("request", try request("20", "repository/conformance", Mutation(
                    requestToken: "2e4a6c8e-0b1d-4f3a-9c5e-7a9b1d3f5e21",
                    request: ConformanceRequest(host: .android, selection: .changed, record: true, device: "emulator-5554")))),
                ("response", try response("20", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: SuiteResult(suite: "conformance:android", phases: [
                    SuiteResult.Phase(name: "tests", passed: true), SuiteResult.Phase(name: "documents", passed: true),
                ]))),
            ], answeredAsWritten: false),
            Example(name: "repository-integrationPackage", messages: [
                ("request", try request("21", "repository/integrationPackage", Mutation(
                    requestToken: "4c6e8a0c-2d3f-4b5a-8e7c-9b1d3f5a7c22", request: IntegrationPackageRequest(editor: .vscode)))),
                ("response", try response("21", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: EditorExtension(
                    artifactUri: "file:///Users/example/StateUI/artifacts/stateui-0.8.5.vsix", extensionId: "idexus.stateui", version: "0.8.5"))),
            ], answeredAsWritten: false),
            Example(name: "repository-integrationInstall", messages: [
                ("request", try request("22", "repository/integrationInstall", Mutation(
                    requestToken: "6e8a0c2e-4f5b-4d7c-9a1e-3d5f7b9c1e23", request: IntegrationInstallRequest(
                        editorExtension: EditorExtension(
                            artifactUri: "file:///Users/example/StateUI/artifacts/stateui-0.8.5.vsix", extensionId: "idexus.stateui", version: "0.8.5"),
                        editorExecutableUri: "file:///Applications/Visual%20Studio%20Code.app/Contents/Resources/app/bin/code")))),
                ("response", try response("22", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: EditorExtension(
                    artifactUri: "file:///Users/example/StateUI/artifacts/stateui-0.8.5.vsix", extensionId: "idexus.stateui", version: "0.8.5"))),
            ], answeredAsWritten: false),
            Example(name: "index-describe", messages: [
                ("request", try request("16", "index/describe", IndexQuery(host: .uikit))),
                ("response", try response("16", IndexContext(
                    host: .uikit, scratchPath: ".build/uikit/index-build", triple: "arm64-apple-ios26.4-simulator",
                    sdk: "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.0.sdk"))),
            ], answeredAsWritten: false),
            Example(name: "index-acquire", messages: [
                ("request", try request("23", "index/acquire", IndexQuery(host: .uikit, rootUris: ["file:///Users/example/Projects/Demo/Notes"]))),
                ("response", try response("23", IndexLease(host: .uikit, rootUris: [], conflict: IndexConflict(
                    rootUri: "file:///Users/example/Projects/Demo/Notes", host: .appkit)))),
            ], answeredAsWritten: false),
            Example(name: "index-clean", messages: [
                ("request", try request("17", "index/clean", IndexQuery(host: nil, rootUris: [
                    "file:///Users/example/Projects/Demo/Notes", "file:///Users/example/Projects/Demo/Other",
                ]))),
                ("response", try response("17", IndexCleaning(
                    removedUris: ["file:///Users/example/Projects/Demo/Notes/.build/uikit/index-build"],
                    conflicts: [IndexConflict(rootUri: "file:///Users/example/Projects/Demo/Other", host: .appkit)]))),
            ], answeredAsWritten: false),
            Example(name: "workspace-create", messages: [
                ("request", try request("10", "workspace/create", Mutation(
                    requestToken: "0b6f2c8e-3d1a-4f5b-8c7e-9a2d4b6c8e10",
                    request: WorkspaceRequest(name: "Demo", parentUri: "file:///Users/example/Projects", release: "0.8.5",
                                              application: "Notes")))),
                ("response", try response("10", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: made)),
            ], answeredAsWritten: false),
            Example(name: "project-useLibrary", messages: [
                ("request", try request("11", "project/useLibrary", Mutation(
                    requestToken: "7c3e1a9b-5f2d-4e8c-a6b4-1d3f5a7c9e20",
                    request: LibraryRequest(projectUri: demo, checkoutUri: "file:///Users/example/StateUI")))),
                ("response", try response("11", OperationHandle(operationId: operation, state: .queued))),
                ("result", try JSONValue(encoding: used)),
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
            send: { frame in written.bytes.withLock { $0 += Array(frame) } }, diagnose: { _ in }, backlog: { 0 })
        var expected: [JSONValue] = []
        for example in try Self.examples() where example.answeredAsWritten {
            for (role, message) in example.messages {
                if role == "result" { continue }
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
