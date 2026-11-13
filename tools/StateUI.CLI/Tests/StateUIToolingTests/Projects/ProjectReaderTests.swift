// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ProjectReaderTests: XCTestCase {
    /// The StateUI repository this test stands in.
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func package(_ files: [String: String]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)").appendingPathComponent("Demo")
        for (path, text) in files {
            let file = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        return folder
    }

    /// A StateUI checkout is a project of its applications - each with its heads, products and tests - building with
    /// the checkout itself, whose release is the library's.
    func testACheckoutIsAProjectOfItsApplications() async throws {
        let project = try await ProjectReader().describe(containing: Self.repository)

        XCTAssertEqual(project.rootUri, FileURI.string(Self.repository.resolvingSymlinksInPath()))
        XCTAssertEqual(project.applications.map(\.id), ["apps/Gallery", "apps/HelloWorld"])
        let hello = try XCTUnwrap(project.applications.last)
        XCTAssertEqual(hello.name, "HelloWorld")
        XCTAssertEqual(hello.declaredHosts, HostFamily.allCases)
        XCTAssertEqual(hello.products, ["HelloWorldUI"])
        XCTAssertEqual(hello.testSuites, ["HelloWorldTests"])
        XCTAssertEqual(hello.libraryUri, project.rootUri)
        XCTAssertEqual(project.libraries.map(\.rootUri), [project.rootUri])
        XCTAssertEqual(project.libraries.first?.release, Release.version)
        XCTAssertEqual(project.libraries.first?.revision?.count, 40)
    }

    /// The project is the nearest folder up that holds an application: inside an application, the application.
    func testTheNearestApplicationIsTheProject() async throws {
        let sources = Self.repository.appendingPathComponent("apps/HelloWorld/Sources")
        let project = try await ProjectReader().describe(containing: sources)

        XCTAssertEqual(project.applications.map(\.id), ["."])
        XCTAssertEqual(project.applications.map(\.name), ["HelloWorld"])
    }

    /// A host this tool inherited reaches no description: SwiftPM reads the package without one.
    func testAnInheritedHostChangesNoDescription() async throws {
        setenv("STATEUI_HOST", "appkit", 1)
        defer { unsetenv("STATEUI_HOST") }
        let project = try await ProjectReader().describe(containing: Self.repository.appendingPathComponent("apps/HelloWorld"))

        XCTAssertEqual(project.applications.first?.products, ["HelloWorldUI"])
    }

    /// The hosts a package has heads for: a `main.swift` in `Platforms/<Host>`, Android's Gradle build there.
    func testAPackagesHostsAreItsHeads() throws {
        let folder = try package([
            "Package.swift": "", "Platforms/UIKit/main.swift": "", "Platforms/Android/build.gradle.kts": "",
            "Platforms/GTK/notes.txt": "",
        ])
        XCTAssertEqual(ProjectReader.hosts(of: folder), [.uikit, .android])
    }

    /// No application in a folder or above it is no project.
    func testAFolderWithoutApplicationsIsNoProject() async throws {
        let folder = try package(["notes.txt": ""])
        do {
            _ = try await ProjectReader().describe(containing: folder)
            XCTFail("a project was found")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .projectNotFound)
        }
    }

    /// A manifest SwiftPM cannot read is a tool's failure, saying where and what SwiftPM said.
    func testAManifestSwiftPMCannotReadIsAToolFailure() async throws {
        let folder = try package([
            "Package.swift": "// swift-tools-version:6.4\nimport PackageDescription\nlet package = Package(nonsense)\n",
            "Platforms/AppKit/main.swift": "",
        ])
        do {
            _ = try await ProjectReader().describe(containing: folder)
            XCTFail("a broken manifest was read")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.contains(folder.lastPathComponent), error.message)
        }
    }

    /// Swift that cannot be found is a missing toolchain, saying how to name it.
    func testSwiftThatCannotBeFoundIsAMissingToolchain() async throws {
        let folder = try package(["Package.swift": "", "Platforms/AppKit/main.swift": ""])
        let reader = ProjectReader(tools: ToolResolver(environment: ["SWIFT_BIN": "/no/such/swift"]))
        do {
            _ = try await reader.describe(containing: folder)
            XCTFail("swift was found")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .missingToolchain)
            XCTAssertTrue(error.message.contains("SWIFT_BIN"), error.message)
        }
    }
}
