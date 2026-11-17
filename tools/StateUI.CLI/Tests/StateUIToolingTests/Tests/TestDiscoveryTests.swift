// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class TestDiscoveryTests: XCTestCase {
    private var root: URL!

    /// A checkout in small: its own package, the library's, three hosts' and a backend's, and an application -
    /// each with a test target but the backend.
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("suites-\(UUID().uuidString)/Checkout")
        let tested = "// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(name: \"P\", targets: [.testTarget(name: \"T\")])\n"
        for folder in ["", "lib/StateUI/Core", "lib/StateUI/StateUI.AppKit", "lib/StateUI/StateUI.GTK/Testing",
                       "lib/StateUI/StateUI.Android/Tests", "lib/StateUI/StateUI.UIKit/Tests", "apps/Notes"] {
            try write(tested, to: "\(folder)/Package.swift")
        }
        try write("// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(name: \"B\")\n", to: "lib/Backends/WebView.GTK/Package.swift")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    private func write(_ text: String, to path: String) throws {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func suites(_ host: HostFamily?) -> [TestSuiteDescription] {
        TestDiscovery.suites(in: root, host: host, applications: [root.appendingPathComponent("apps/Notes")])
    }

    /// AppKit runs the library, its own package as its suite and the application as an AppKit head, and no other
    /// host's; a package with no test target is no suite.
    func testAppKitRunsItsOwnPackageAndItsApplicationsAsHeads() {
        let found = suites(.appkit)
        XCTAssertEqual(found.map(\.id), ["Checkout", "lib/StateUI/Core", "lib/StateUI/StateUI.AppKit", "apps/Notes"])
        XCTAssertEqual(found.map(\.kind), [.package, .package, .host, .package])
        XCTAssertEqual(found.map(\.host), [nil, nil, .appkit, .appkit])
        XCTAssertFalse(found.contains { $0.onDevice })
    }

    /// With no host every package but a host's runs as plain Swift.
    func testNoHostRunsEveryPackageButTheHostsAsPlainSwift() {
        let found = suites(nil)
        XCTAssertEqual(found.map(\.id), ["Checkout", "lib/StateUI/Core", "apps/Notes"])
        XCTAssertTrue(found.allSatisfy { $0.kind == .package && $0.host == nil && !$0.onDevice })
    }

    /// A host whose tests stand in a `Testing` package runs that package as its suite.
    func testATestingPackageIsItsHostsSuite() {
        let found = suites(.gtk)
        XCTAssertEqual(found.map(\.id), ["Checkout", "lib/StateUI/Core", "lib/StateUI/StateUI.GTK/Testing", "apps/Notes"])
        XCTAssertEqual(found[2].kind, .host)
        XCTAssertEqual(found[2].host, .gtk)
        XCTAssertNil(found[3].host, "an application runs as plain Swift for GTK")
    }

    /// Android and UIKit run their host's suite last, on a device, and the application as plain Swift.
    func testADevicesSuiteRunsLastOnTheDevice() {
        for (host, folder) in [(HostFamily.android, "lib/StateUI/StateUI.Android/Tests"), (.uikit, "lib/StateUI/StateUI.UIKit/Tests")] {
            let found = suites(host)
            XCTAssertEqual(found.map(\.id), ["Checkout", "lib/StateUI/Core", "apps/Notes", folder], "\(host)")
            XCTAssertEqual(found.filter(\.onDevice).map(\.id), [folder], "\(host)")
            XCTAssertEqual(found.last?.host, host)
            XCTAssertEqual(found.last?.packageUri, FileURI.string(root.appendingPathComponent(folder)))
        }
    }

    /// A suite is named by its package's path from the folder, the same on every platform.
    func testASuiteIsNamedByItsPathWithForwardSlashes() {
        XCTAssertTrue(suites(.gtk).allSatisfy { !$0.id.contains("\\") })
        XCTAssertEqual(TestDiscovery.host(of: root.appendingPathComponent("lib/Backends/WebView.GTK")), .gtk)
        XCTAssertNil(TestDiscovery.host(of: root.appendingPathComponent("apps/Notes")))
    }

    /// A run takes a suite the folder holds for the host, and a device for a suite that runs on one.
    func testARunTakesAHeldSuiteAndADevicesSuiteItsDevice() async throws {
        try write(
            #"{ "schemaVersion": 1, "library": { "path": "." }, "projects": ["apps/Notes"] }"#, to: "stateui-workspace.json")
        try write("", to: "apps/Notes/Platforms/AppKit/Package.swift")
        try write(#"{"build":1,"identifier":"com.example.notes","schemaVersion":1,"version":"1.0.0"}"#, to: "apps/Notes/stateui.json")
        let service = ToolingService()
        let listed = try await service.discoverTests(for: .android, in: root)
        XCTAssertEqual(listed.suites.map(\.id), ["Checkout", "lib/StateUI/Core", "apps/Notes", "lib/StateUI/StateUI.Android/Tests"])
        for (suite, refusal) in [("lib/StateUI/StateUI.AppKit", "No suite"), ("lib/StateUI/StateUI.Android/Tests", "runs on a device")] {
            do {
                _ = try await service.runTests(TestRunRequest(suite: suite, host: .android), in: root, reporter: BuildReporter())
                XCTFail("\(suite) ran")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, .invalidConfiguration)
                XCTAssertTrue(error.message.contains(refusal), error.message)
            }
        }
    }
}
