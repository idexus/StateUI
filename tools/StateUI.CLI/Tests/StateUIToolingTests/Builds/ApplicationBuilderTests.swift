// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

/// The builder's order, with a stand-in for SwiftPM: it describes the application, says where it laid the product,
/// and builds it - or fails, as `FAIL` beside it says.
final class ApplicationBuilderTests: XCTestCase {
    private struct Bench {
        var root: URL
        var application: URL
        var environment: [String: String]
        var permit: BuildPermit
        var failing: URL
        var arguments: URL
    }

    private func bench() throws -> Bench {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("builder-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let checkout = root.appendingPathComponent("StateUI")
        for mark in ["lib/StateUI.Head", "apps/HelloWorld"] {
            try files.createDirectory(at: checkout.appendingPathComponent(mark), withIntermediateDirectories: true)
            try Data().write(to: checkout.appendingPathComponent(mark).appendingPathComponent("Package.swift"))
        }
        try Data().write(to: checkout.appendingPathComponent("Package.swift"))
        let application = root.appendingPathComponent("Notes")
        for host in ["AppKit", "UIKit"] {
            try files.createDirectory(at: application.appendingPathComponent("Platforms/\(host)"), withIntermediateDirectories: true)
            try Data().write(to: application.appendingPathComponent("Platforms/\(host)/main.swift"))
        }
        try Data().write(to: application.appendingPathComponent("Package.swift"))
        let bin = root.appendingPathComponent("bin")
        let failing = root.appendingPathComponent("FAIL")
        let arguments = root.appendingPathComponent("arguments")
        let swift = root.appendingPathComponent("swift")
        let describe = #"{"dependencies":[{"identity":"stateui","path":"\#(checkout.path)"}],"products":[{"name":"NotesUI"}],"targets":[{"name":"NotesTests","type":"test"}]}"#
        let script = """
            #!/bin/sh
            case "$1 $2" in
              "package describe") echo '\(describe)' ;;
              "--version ") echo 'Swift version 6.4.2 (swift-6.4.2-RELEASE)' ;;
              "build --show-bin-path") echo '\(bin.path)' ;;
              "build --product")
                if [ -e '\(failing.path)' ]; then echo 'error: the compiler stopped'; exit 1; fi
                [ "Notes$STATEUI_HOST" = "$(echo "$3" | tr '[:upper:]' '[:lower:]' | sed 's/^notes/Notes/')" ] || { echo 'no host'; exit 1; }
                echo "$@" > '\(arguments.path)'
                mkdir -p '\(bin.path)' && cp /usr/bin/true "\(bin.path)/$3" && echo 'Build complete!' ;;
            esac
            """
        try script.write(to: swift, atomically: true, encoding: .utf8)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)
        let permit = BuildPermit(folder: root.appendingPathComponent("state"))
        return Bench(root: root, application: application, environment: ["SWIFT_BIN": swift.path, "PATH": "/usr/bin:/bin"],
                     permit: permit, failing: failing, arguments: arguments)
    }

    /// A build publishes its bundle and journals its operation; a later build that fails publishes nothing, says
    /// why, and leaves the last bundle as it was.
    func testABuildPublishesAndAFailedOneLeavesTheLast() async throws {
        let bench = try bench()
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)
        let request = BuildRequest(host: .appkit)

        let built = try await builder.build(request, in: bench.application, operation: "op-1")
        let program = try FileURI.url(built.programUri)
        XCTAssertTrue(program.path.hasSuffix("NotesAppKit.app/Contents/MacOS/NotesAppKit"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: program.path))
        XCTAssertEqual(built.configuration, .debug)
        let journal = OperationJournal(root: try FileURI.url(FileURI.string(bench.application)))
        XCTAssertEqual(try journal.record(of: "op-1").state, .succeeded)
        let written = try FileManager.default.attributesOfItem(atPath: program.path)[.modificationDate] as? Date

        try Data().write(to: bench.failing)
        do {
            _ = try await builder.build(request, in: bench.application, operation: "op-2")
            XCTFail("a failed build published")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.contains("the compiler stopped"), error.message)
        }
        XCTAssertEqual(try journal.record(of: "op-2").state, .failed)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: program.path)[.modificationDate] as? Date, written)
        XCTAssertNil(bench.permit.holder)
    }

    /// A host the tool does not build yet, an application without its head, and an application not named among
    /// several are refused before anything runs.
    func testWhatCannotBeBuiltIsRefusedFirst() async throws {
        let bench = try bench()
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)
        for (request, said) in [(BuildRequest(host: .gtk), "has no gtk head"), (BuildRequest(host: .uikit, device: "Nothing"), "No iPhone")] {
            do {
                _ = try await builder.build(request, in: bench.application, operation: "op")
                XCTFail("\(request.host) was built")
            } catch let error as ToolingError {
                XCTAssertTrue(error.message.contains(said), error.message)
            }
        }
    }

    /// A UIKit head is built for the destination chosen - the booted simulator where none is named - with its triple
    /// and SDK, then bundled and signed ad hoc; the result says the bundle, its program and the destination.
    func testAUIKitHeadIsBuiltForTheSimulatorChosen() async throws {
        let bench = try bench()
        let simulators = [
            Destination(id: "PHONE", udid: "PHONE", name: "iPhone 18 Pro", kind: .simulator, version: "27.0"),
            Destination(id: "PAD", udid: "PAD", name: "iPad Air 13-inch (M4)", kind: .simulator, version: "27.0", booted: true),
        ]
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit, destinations: { simulators })

        let built = try await builder.build(BuildRequest(host: .uikit), in: bench.application, operation: "op-uikit")

        XCTAssertEqual(built.destination?.id, "PAD")
        XCTAssertTrue(built.programUri.hasSuffix("NotesUIKit.app/NotesUIKit"), built.programUri)
        XCTAssertTrue(try XCTUnwrap(built.bundleUri).hasSuffix("NotesUIKit.app"))
        let said = try String(contentsOf: bench.arguments, encoding: .utf8)
        XCTAssertTrue(said.contains("--triple arm64-apple-ios26.4-simulator"), said)
        XCTAssertTrue(said.contains("--sdk ") && said.contains("iPhoneSimulator"), said)
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: try FileURI.url(XCTUnwrap(built.bundleUri)).appendingPathComponent("Info.plist")), format: nil)
            as? [String: Any])
        XCTAssertEqual(plist["CFBundleSupportedPlatforms"] as? [String], ["iPhoneSimulator"])

        let laid = bench.root.appendingPathComponent("laid")
        let packaged = try await builder.package(
            BuildRequest(host: .uikit, device: "iPhone 18 Pro", outputUri: FileURI.string(laid)), in: bench.application,
            operation: "op-package")
        XCTAssertEqual(packaged.destination?.id, "PHONE")
        XCTAssertEqual(packaged.configuration, .release)
        XCTAssertTrue(FileManager.default.fileExists(atPath: laid.appendingPathComponent("NotesUIKit.app/NotesUIKit").path))
        XCTAssertEqual(try FileURI.url(packaged.programUri).path, laid.appendingPathComponent("NotesUIKit.app/NotesUIKit").path)
    }
}
#endif
