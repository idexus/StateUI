// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUIToolingProtocol
import StateUITooling
import Synchronization
import XCTest

final class ProjectServiceTests: XCTestCase {
    /// `project/describe` with no project named describes the workspace its connection opened, an answer read
    /// whole as a `Project`; with one named, that one.
    func testProjectDescribeReadsTheConnectionsWorkspace() async throws {
        let hello = ProjectReaderTests.repository.appendingPathComponent("apps/HelloWorld")
        let frames = Frames()
        let connection = Connection(
            server: ToolingService.identity, apiVersions: Release.apiVersions, methods: ToolingService().methods,
            send: frames.add, diagnose: { _ in }, backlog: { 0 })
        let messages = [
            #"{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"apiVersions":[{"major":1,"minMinor":0,"maxMinor":0}],"#
                + #""client":{"name":"test","version":"1"},"workspaceUri":"\#(FileURI.string(hello))"}}"#,
            #"{"jsonrpc":"2.0","method":"initialized"}"#,
            #"{"jsonrpc":"2.0","id":"2","method":"project/describe","params":{}}"#,
            #"{"jsonrpc":"2.0","id":"3","method":"project/describe","params":{"projectUri":"\#(FileURI.string(ProjectReaderTests.repository))"}}"#,
        ]
        for message in messages {
            _ = await connection.receive(Data("Content-Length: \(message.utf8.count)\r\n\r\n\(message)".utf8))
            await connection.settle()
        }
        let answers = try frames.messages().dropFirst()
        let projects = try answers.map { try XCTUnwrap($0["result"]).decode(Project.self) }

        XCTAssertEqual(projects.map { $0.applications.map(\.name) }, [["HelloWorld"], ["Gallery", "HelloWorld"]])
    }

    /// `name/check` answers by the name's rule first, then by the folder it would be made in: one taken - holding
    /// files, or a file - refuses it, an empty one or none takes it.
    func testANameIsCheckedByItsRuleThenItsFolder() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("names-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: parent) }
        let files = FileManager.default
        try files.createDirectory(at: parent.appendingPathComponent("Held/Sources"), withIntermediateDirectories: true)
        try files.createDirectory(at: parent.appendingPathComponent("Empty"), withIntermediateDirectories: true)
        try Data().write(to: parent.appendingPathComponent("File"))
        let service = ToolingService()

        XCTAssertNil(service.checkName("Notes", of: .application, in: parent).problem)
        XCTAssertNil(service.checkName("Empty", of: .application, in: parent).problem)
        XCTAssertNil(service.checkName("Notes", of: .application, in: nil).problem)
        XCTAssertEqual(service.checkName("My-App", of: .application, in: parent).problem,
                       "'My-App' cannot name an application: letters and digits only, starting with a letter.")
        XCTAssertEqual(service.checkName("StateUI", of: .application, in: nil).problem,
                       "'StateUI' is the library. Pick a name of the application's own.")
        XCTAssertNil(service.checkName("My.Apps-2_x", of: .workspace, in: parent).problem)
        XCTAssertNotNil(service.checkName("My Apps", of: .workspace, in: nil).problem)
        XCTAssertNotNil(service.checkName("-apps", of: .workspace, in: nil).problem)
        XCTAssertTrue(try XCTUnwrap(service.checkName("Held", of: .application, in: parent).problem).hasSuffix("already holds files."))
        XCTAssertTrue(try XCTUnwrap(service.checkName("File", of: .workspace, in: parent).problem).hasSuffix("already exists."))
    }
}

/// The frames a connection wrote.
final class Frames: Sendable {
    private let bytes = Mutex<[UInt8]>([])

    @Sendable func add(_ frame: Data) {
        bytes.withLock { $0 += Array(frame) }
    }

    func messages() throws -> [JSONValue] {
        var reader = FrameReader()
        return try reader.take(bytes.withLock { $0 }).map { try ToolingJSON.decoder().decode(JSONValue.self, from: $0) }
    }
}

extension JSONValue {
    subscript(_ key: String) -> JSONValue? {
        if case .object(let object) = self { object[key] } else { nil }
    }
}
