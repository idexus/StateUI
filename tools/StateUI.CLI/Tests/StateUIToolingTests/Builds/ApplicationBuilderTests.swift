// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@testable import StateUITooling
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
        /// A script the build runs as it builds, where one stands.
        var during: URL
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
            try Data().write(to: application.appendingPathComponent("Platforms/\(host)/Package.swift"))
        }
        try Data().write(to: application.appendingPathComponent("Package.swift"))
        try ApplicationFile(identifier: "com.example.notes", version: "1.0.0", build: 1)
            .write(to: application.appendingPathComponent("stateui.json"))
        let bin = root.appendingPathComponent("bin")
        let failing = root.appendingPathComponent("FAIL")
        let arguments = root.appendingPathComponent("arguments")
        let during = root.appendingPathComponent("DURING")
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
                all="$*"; rest="${all#*--package-path }"; head="${rest%% *}"; [ "Notes${head##*/}" = "$3" ] || { echo 'no head'; exit 1; }
                echo "$@" > '\(arguments.path)'
                if [ -e '\(during.path)' ]; then sh '\(during.path)'; fi
                mkdir -p '\(bin.path)' && cp /usr/bin/true "\(bin.path)/$3" && echo 'Build complete!' ;;
            esac
            """
        try script.write(to: swift, atomically: true, encoding: .utf8)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)
        let permit = BuildPermit(folder: root.appendingPathComponent("state"))
        return Bench(root: root, application: application, environment: ["SWIFT_BIN": swift.path, "PATH": "/usr/bin:/bin"],
                     permit: permit, failing: failing, arguments: arguments, during: during)
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
        for (request, said) in [(BuildRequest(host: .gtk), "has no gtk head"), (BuildRequest(host: .uikit, device: "Nothing"), "No iPhone"),
                                (BuildRequest(host: .android), "has no android head")] {
            do {
                _ = try await builder.build(request, in: bench.application, operation: "op")
                XCTFail("\(request.host?.rawValue ?? "no host") was built")
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
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit, destinations: { _ in simulators })

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

    /// In a workspace of several applications, a build naming none builds the one its file starts.
    func testAWorkspacesStartupIsBuiltWhereNoneIsNamed() async throws {
        let bench = try bench()
        let files = FileManager.default
        let other = bench.root.appendingPathComponent("Other")
        try files.createDirectory(at: other.appendingPathComponent("Platforms/AppKit"), withIntermediateDirectories: true)
        try Data().write(to: other.appendingPathComponent("Platforms/AppKit/Package.swift"))
        try Data().write(to: other.appendingPathComponent("Package.swift"))
        try ApplicationFile(identifier: "com.example.other", version: "1.0.0", build: 1)
            .write(to: other.appendingPathComponent("stateui.json"))
        try WorkspaceFile(library: .init(path: "StateUI"), projects: ["Notes", "Other"])
            .write(to: bench.root.appendingPathComponent("stateui-workspace.json"))
        try WorkspaceSettings(startup: "Notes").write(to: WorkspaceSettings.file(in: bench.root))
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)

        let built = try await builder.build(BuildRequest(host: .appkit), in: bench.root, operation: "op-startup")

        XCTAssertEqual(built.application, "Notes")
    }

    /// A build naming no host builds for the one chosen for its application; with none chosen it is refused, saying
    /// how to choose.
    func testABuildNamingNoHostBuildsForTheOneChosen() async throws {
        let bench = try bench()
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)
        do {
            _ = try await builder.build(BuildRequest(), in: bench.application, operation: "op-no-host")
            XCTFail("a build with no host ran")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .invalidConfiguration)
            XCTAssertTrue(error.message.contains("stateui settings --host"), error.message)
        }

        try ApplicationSettings(host: .appkit).write(to: ApplicationSettings.file(in: bench.application))
        let built = try await builder.build(BuildRequest(), in: bench.application, operation: "op-chosen")

        XCTAssertEqual(built.host, .appkit)
    }

    /// A head whose platform keeps no record of the application - WinUI's, GTK's, a page - carries its `stateui.json`,
    /// the name shown in it; a bundle and an APK, whose platform keeps one, carry none.
    func testAHeadOfNoRecordCarriesTheApplicationsFile() throws {
        let identity = ApplicationFile(identifier: "pl.example.notes", version: "2.1", build: 9, name: "Notes")
        for host in HostFamily.allCases {
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("head-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            try ApplicationBuilder.lay(identity, for: host, in: staging)
            let file = staging.appendingPathComponent("stateui.json")
            XCTAssertEqual(FileManager.default.fileExists(atPath: file.path), [.web, .winui, .gtk].contains(host), host.rawValue)
            if [.web, .winui, .gtk].contains(host) {
                XCTAssertEqual(try ApplicationFile.read(file), identity)
            }
        }
    }

    /// A package replaces only a folder a package was laid in: one holding anything else is refused before any build,
    /// and so is the application's folder or one holding it - what stood there stays. A folder it laid it lays again.
    func testAPackageReplacesOnlyAFolderAPackageWasLaidIn() async throws {
        let bench = try bench()
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)
        let files = FileManager.default

        let kept = bench.root.appendingPathComponent("kept")
        try files.createDirectory(at: kept, withIntermediateDirectories: true)
        try Data("mine".utf8).write(to: kept.appendingPathComponent("keep.txt"))
        for output in [kept, bench.application, bench.root] {
            do {
                _ = try await builder.package(
                    BuildRequest(host: .appkit, outputUri: FileURI.string(output)), in: bench.application, operation: "op-refused")
                XCTFail("\(output.lastPathComponent) was laid over")
            } catch let error as ToolingError {
                XCTAssertTrue([.alreadyExists, .invalidConfiguration].contains(error.code), error.message)
            }
        }
        XCTAssertEqual(try String(contentsOf: kept.appendingPathComponent("keep.txt"), encoding: .utf8), "mine")
        XCTAssertTrue(files.fileExists(atPath: bench.application.appendingPathComponent("Package.swift").path))
        XCTAssertFalse(files.fileExists(atPath: bench.arguments.path), "nothing was built")

        let laid = bench.root.appendingPathComponent("laid")
        for _ in 0..<2 {
            _ = try await builder.package(
                BuildRequest(host: .appkit, outputUri: FileURI.string(laid)), in: bench.application, operation: "op-laid")
        }
        XCTAssertTrue(files.fileExists(atPath: laid.appendingPathComponent("NotesAppKit.app").path))
    }

    /// A folder is judged again as the package is laid: what came to stand in it while the build ran - in one that
    /// stood empty, in one that did not stand - stays, and the package is refused.
    func testAPackageLeavesWhatCameToItsFolderWhileItWasBuilt() async throws {
        let bench = try bench()
        let builder = ApplicationBuilder(environment: bench.environment, permit: bench.permit)
        let files = FileManager.default
        let empty = bench.root.appendingPathComponent("empty")
        try files.createDirectory(at: empty, withIntermediateDirectories: true)

        for output in [empty, bench.root.appendingPathComponent("absent")] {
            try "mkdir -p '\(output.path)' && echo mine > '\(output.path)/keep.txt'"
                .write(to: bench.during, atomically: true, encoding: .utf8)
            do {
                _ = try await builder.package(
                    BuildRequest(host: .appkit, outputUri: FileURI.string(output)), in: bench.application, operation: "op-during")
                XCTFail("\(output.lastPathComponent) was laid over")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, .alreadyExists, error.message)
            }
            XCTAssertEqual(try files.contentsOfDirectory(atPath: output.path), ["keep.txt"], output.lastPathComponent)
            XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("keep.txt"), encoding: .utf8), "mine\n")
        }
    }
}
#endif
