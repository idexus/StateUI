// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import XCTest

final class AndroidToolsTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("android-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func executable(_ file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    /// The SDK's adb and emulator stand where Android Studio lays them; aapt2 is the newest build tools'.
    func testTheSDKsToolsAreItsOwnTheNewestBuildTools() throws {
        let sdk = try folder()
        for version in ["34.0.0", "36.1.0", "9.0.0"] {
            try executable(sdk.appendingPathComponent("build-tools/\(version)/aapt2\(AndroidTools.programSuffix)"))
        }
        let tools = AndroidTools(environment: ["ANDROID_HOME": sdk.path])
        let suffix = AndroidTools.programSuffix
        XCTAssertEqual(tools.adb.path, sdk.appendingPathComponent("platform-tools/adb\(suffix)").path)
        XCTAssertEqual(tools.emulator.path, sdk.appendingPathComponent("emulator/emulator\(suffix)").path)
        XCTAssertEqual(tools.aapt2?.path, sdk.appendingPathComponent("build-tools/36.1.0/aapt2\(suffix)").path)
        XCTAssertNil(AndroidTools(environment: ["ANDROID_HOME": try folder().path]).aapt2)
    }

    /// An NDK's major release is read from its `source.properties`.
    func testAnNDKsReleaseIsItsSourceProperties() throws {
        let ndk = try folder()
        try "Pkg.Desc = Android NDK\nPkg.Revision = 30.0.14904198\n".write(
            to: ndk.appendingPathComponent("source.properties"), atomically: true, encoding: .utf8)
        XCTAssertEqual(AndroidTools.ndkMajor(of: ndk), 30)
        XCTAssertNil(AndroidTools.ndkMajor(of: try folder()))
    }

    /// The pinned Gradle is the wrapper cache's where it stands there; nothing is downloaded to say so.
    func testGradleIsTheWrapperCachesWhereItStands() throws {
        let home = try folder()
        let tools = AndroidTools(environment: [:], home: home)
        XCTAssertNil(tools.cachedGradle)
        let gradle = home.appendingPathComponent(".gradle/wrapper/dists/gradle-\(AndroidTools.gradleVersion)-bin/abc123/gradle-\(AndroidTools.gradleVersion)/bin/\(AndroidTools.gradleLauncher)")
        try executable(gradle)
        XCTAssertEqual(tools.cachedGradle?.path, gradle.path)
    }
}
