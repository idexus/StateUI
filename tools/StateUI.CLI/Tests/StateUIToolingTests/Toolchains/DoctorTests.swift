// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class DoctorTests: XCTestCase {
    private func finding(_ hosts: [HostFamily], found: Bool) -> ToolFinding {
        ToolFinding(component: "c", neededBy: "n", hosts: hosts, found: found ? "1" : nil, tooOld: nil, advice: "a")
    }

    /// A report lacks for a host what that host cannot be built without; with no host named, what every host needs.
    func testAReportLacksWhatAHostCannotDoWithout() {
        let report = ToolchainReport(findings: [
            finding(HostFamily.allCases, found: true), finding([.android], found: false), finding([], found: false),
        ])
        XCTAssertTrue(report.lacks(for: .android))
        XCTAssertFalse(report.lacks(for: .appkit))
        XCTAssertFalse(report.lacks(for: nil))
        XCTAssertTrue(ToolchainReport(findings: [finding(HostFamily.allCases, found: false)]).lacks(for: nil))
    }

    /// This machine's Swift is found, first, by the compiler `SWIFT_BIN` names or the search path's - where the tests
    /// themselves were built with one.
    func testThisMachinesSwiftIsFoundFirst() async {
        let report = await Doctor().check()
        XCTAssertEqual(report.findings.first?.component, "Swift 6.4 or newer")
        XCTAssertNotNil(report.findings.first?.found)
        XCTAssertEqual(report.findings.first?.hosts, HostFamily.allCases)
    }

    /// A program on the search path is found by its name - with Windows' own extensions there.
    func testAProgramOnTheSearchPathIsFound() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #if os(Windows)
        let (file, separator) = (folder.appendingPathComponent("tool.exe"), ";")
        #else
        let (file, separator) = (folder.appendingPathComponent("tool"), ":")
        #endif
        try "".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        let path = SearchPath(environment: ["PATH": "/no/such\(separator)\(folder.path)", "PATHEXT": ".EXE"])

        XCTAssertEqual(path.find("tool")?.resolvingSymlinksInPath().path, file.resolvingSymlinksInPath().path)
        XCTAssertNil(path.find("absent"))
    }

    /// The NDK the build takes: the one the environment names, else the Android SDK's newest.
    func testTheNDKTheEnvironmentNamesComesFirst() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        let ndk = { (folder: URL) throws -> URL in
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent("toolchains/llvm/prebuilt"), withIntermediateDirectories: true)
            return folder
        }
        let named = try ndk(root.appendingPathComponent("named"))
        _ = try ndk(root.appendingPathComponent("sdk/ndk/29.0.1"))
        let newest = try ndk(root.appendingPathComponent("sdk/ndk/30.0.2"))
        let sdk = root.appendingPathComponent("sdk").path

        XCTAssertEqual(
            AndroidTools(environment: ["ANDROID_NDK_HOME": named.path, "ANDROID_HOME": sdk]).ndk(for: nil)?.path, named.path)
        XCTAssertEqual(AndroidTools(environment: ["ANDROID_HOME": sdk]).ndk(for: nil)?.path, newest.path)
        XCTAssertEqual(AndroidTools(environment: ["ANDROID_SDK_ROOT": sdk]).sdk.path, sdk)
    }

    /// Android's Swift is the compiler the build takes - the search path's - with the Swift SDK of its release, not
    /// the first swift.org toolchain with any; where the search path's is Xcode's, the swift.org one of its release.
    func testAndroidsSwiftIsTheOneTheBuildTakes() async throws {
        #if os(Windows)
        throw XCTSkip("Android's tools are looked for on macOS")
        #else
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        // Another release than the manifests' is assembled from parts: the repository names one Swift (ToolchainTests).
        let current = "6.4" + ".2", earlier = "6.4" + ".0"
        let sdks = "swift-\(earlier)-RELEASE_android\nswift-\(current)-RELEASE_android\n"
        let compiler = { (folder: URL, says: String) throws -> URL in
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let program = folder.appendingPathComponent("swift")
            let script = "#!/bin/sh\nif [ \"$1\" = sdk ]; then printf '\(sdks)'; else echo '\(says)'; fi\n"
            try script.write(to: program, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)
            return program
        }
        let toolchains = root.appendingPathComponent("home/Library/Developer/Toolchains")
        _ = try compiler(toolchains.appendingPathComponent("swift-\(earlier)-RELEASE.xctoolchain/usr/bin"),
                         "Swift version \(earlier) (swift-\(earlier)-RELEASE)")
        let swiftOrg = try compiler(toolchains.appendingPathComponent("swift-\(current)-RELEASE.xctoolchain/usr/bin"),
                                    "Swift version \(current) (swift-\(current)-RELEASE)")
        let onPath = try compiler(root.appendingPathComponent("bin"), "Swift version \(current) (swift-\(current)-RELEASE)")
        let xcode = try compiler(root.appendingPathComponent("xcode"), "Apple Swift version \(current) (swiftlang-6.4.2.1.1)")
        let home = root.appendingPathComponent("home")

        let taken = await AndroidTools(environment: ["PATH": onPath.deletingLastPathComponent().path], home: home).swift()
        XCTAssertEqual(taken?.compiler.path, onPath.path)
        XCTAssertEqual(taken?.sdk, "swift-\(current)-RELEASE_android")
        let behindXcode = await AndroidTools(environment: ["SWIFT_BIN": xcode.path], home: home).swift()
        XCTAssertEqual(behindXcode?.compiler.path, swiftOrg.path)
        XCTAssertEqual(behindXcode?.sdk, "swift-\(current)-RELEASE_android")
        #endif
    }
}
