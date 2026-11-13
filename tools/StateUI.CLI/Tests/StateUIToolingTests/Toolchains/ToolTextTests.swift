// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUITooling
import XCTest

final class ToolTextTests: XCTestCase {
    /// Versions compare part by part, a missing part counting as 0.
    func testVersionsCompareByPart() {
        XCTAssertTrue(Versions.atLeast("6.4.1", "6.4"))
        XCTAssertTrue(Versions.atLeast("26", "26.0"))
        XCTAssertFalse(Versions.atLeast("6.10", "6.11"))
        XCTAssertTrue(Versions.compare("10.0", "9.9") > 0)
        XCTAssertEqual(Versions.first(in: "git version 2.54.0 (Apple)"), "2.54.0")
    }

    /// Swift's release is read from what `swift --version` says, a `.0` patch left off; a swift.org build says so.
    func testSwiftsReleaseIsReadFromItsVersion() {
        let swiftOrg = "Apple Swift version 6.4 (swift-6.4-RELEASE)\nTarget: arm64-apple-macosx26.0"
        XCTAssertEqual(Versions.swiftRelease(in: swiftOrg), "6.4")
        XCTAssertEqual(Versions.swiftRelease(in: "Swift version 6.4.0 (swift-6.4-RELEASE)"), "6.4")
        // Another release than the manifests' is assembled from parts: the repository names one Swift (ToolchainTests).
        let patch = "6.4" + ".1"
        XCTAssertEqual(Versions.swiftRelease(in: "Swift version \(patch) (swift-\(patch)-RELEASE)"), patch)
        XCTAssertTrue(Versions.isSwiftOrgBuild(swiftOrg))
        XCTAssertFalse(Versions.isSwiftOrgBuild("Apple Swift version 6.4 (swiftlang-6.4.0.1.2 clang-1800.0.1)"))
    }

    /// A Swift SDK is the last of Swift's release whose id ends in the family asked, never an Embedded sibling.
    func testASwiftSDKIsOfSwiftsReleaseAndFamily() {
        let older = "6" + ".3"
        let list = "swift-\(older)-RELEASE_android\nswift-6.4.0-RELEASE_wasm\nswift-6.4.0-RELEASE_wasm-embedded\nswift-6.4-RELEASE_android"
        XCTAssertEqual(Versions.swiftSDK(of: "6.4", in: list, family: "wasm"), "swift-6.4.0-RELEASE_wasm")
        XCTAssertEqual(Versions.swiftSDK(of: "6.4", in: list, family: "android"), "swift-6.4-RELEASE_android")
        XCTAssertNil(Versions.swiftSDK(of: "6.5", in: list, family: "android"))
        XCTAssertNil(Versions.swiftSDK(of: nil, in: list, family: "wasm"))
    }

    /// Apple's tools are read for Xcode's version, the newest iOS runtime and the first development identity.
    func testApplesToolsAreRead() {
        XCTAssertEqual(ToolText.xcodeVersion(in: "Xcode 27.1\nBuild version 27B100"), "27.1")
        let runtimes = #"{"runtimes":[{"platform":"iOS","version":"26.4","isAvailable":true},"#
            + #"{"name":"iOS 27.1","version":"27.1"},{"platform":"watchOS","version":"30.0"},"#
            + #"{"platform":"iOS","version":"28.0","isAvailable":false}]}"#
        XCTAssertEqual(ToolText.newestIOSRuntime(in: runtimes), "27.1")
        XCTAssertNil(ToolText.newestIOSRuntime(in: "not json"))
        let identities = #"  1) 0123 "Developer ID Application: Someone" "#
            + "\n" + #"  2) 4567 "Apple Development: Jane Doe (ABCDE12345)""#
        XCTAssertEqual(ToolText.developmentIdentity(in: identities), "Apple Development: Jane Doe (ABCDE12345)")
    }

    /// An NDK's release is its properties' revision.
    func testAnNDKsReleaseIsItsRevision() {
        XCTAssertEqual(ToolText.ndkRevision(in: "Pkg.Desc = Android NDK\nPkg.Revision = 30.0.16248370\n"), "30.0.16248370")
        XCTAssertNil(ToolText.ndkRevision(in: "Pkg.Desc = Android NDK\n"))
    }

    /// GTK's SVG loader is found in gdk-pixbuf's cache, or in a glycin config's SVG section.
    func testGTKsSVGLoaderIsFound() {
        let cache = """
        # GdkPixbuf Image Loader Modules file
        "/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-png.so"
        "png" 5 "gdk-pixbuf" "PNG" "LGPL"
        "image/png" ""

        "/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so"
        "svg" 6 "gdk-pixbuf" "Scalable Vector Graphics" "LGPL"
        "image/svg+xml" "image/svg" ""
        """
        XCTAssertEqual(ToolText.svgLoader(inCache: cache), "libpixbufloader_svg.so")
        let glycin = "[loader:image/png]\nExec = /usr/libexec/glycin-loaders/2+/glycin-image-rs\n\n"
            + "[loader:image/svg+xml]\nExec = /usr/libexec/glycin-loaders/2+/glycin-svg\n"
        XCTAssertEqual(ToolText.svgLoader(inGlycinConfig: glycin), "glycin-svg")
        XCTAssertNil(ToolText.svgLoader(inGlycinConfig: "[loader:image/png]\nExec = x\n"))
    }
}
