// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ProductFolderTests: XCTestCase {
    /// A SwiftPM warning as it answers: the folder is the last line of its standard output, never a line of its errors.
    func testTheFolderIsWhatSwiftPMPrintedToItsStandardOutput() async throws {
        let swift = try fake("echo /work/.build/debug; echo \"warning: 'work': found 1 file(s) which are unhandled\" >&2")
        let folder = try await ProductFolder.of(.path(swift.path), placing: ["--package-path", "/work"])
        XCTAssertEqual(folder.path, "/work/.build/debug")
    }

    /// A SwiftPM that refuses is told by what it said and how it ended.
    func testARefusalSaysWhatSwiftPMSaidAndHowItEnded() async throws {
        let swift = try fake("echo 'error: Could not find Package.swift in this directory' >&2; exit 1")
        do {
            let folder = try await ProductFolder.of(.path(swift.path), placing: ["--package-path", "/work"])
            XCTFail("a refusal named \(folder.path)")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.hasPrefix("SwiftPM did not say where it laid the build"), error.message)
            XCTAssertTrue(error.message.contains("it exited with status 1"), error.message)
            XCTAssertTrue(error.message.contains("error: Could not find Package.swift in this directory"), error.message)
        }
    }

    /// SwiftPM is asked by the arguments that placed the build: its package, scratch, configuration, triple and SDK.
    func testSwiftPMIsAskedByTheArgumentsThatPlacedTheBuild() async throws {
        let swift = try fake("echo \"$*\" > \"$(dirname \"$0\")/asked\"; echo /work/.build/debug")
        _ = try await ProductFolder.of(.path(swift.path), placing: ["--package-path", "/work", "--triple", "arm64-apple-ios27.0-simulator"])
        let asked = try String(contentsOf: swift.deletingLastPathComponent().appendingPathComponent("asked"), encoding: .utf8)
        XCTAssertEqual(asked, "build --show-bin-path --package-path /work --triple arm64-apple-ios27.0-simulator\n")
    }

    /// A program named `swift` in a folder of its own, running `script` in a shell; the folder goes when the test ends.
    private func fake(_ script: String) throws -> URL {
        #if os(Windows)
        throw XCTSkip("the stand-in SwiftPM is a shell's")
        #else
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("swiftpm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let swift = folder.appendingPathComponent("swift")
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: swift)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swift.path)
        return swift
        #endif
    }
}
