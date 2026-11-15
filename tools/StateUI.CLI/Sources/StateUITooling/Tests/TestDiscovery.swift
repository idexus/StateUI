// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The suites a folder holds for a host, in the order they are best run: the library's packages, the hosts' own -
/// a host's package, or its tests' own `Testing` package, runs only as that host, as its suite - then the folder's
/// applications, an AppKit host's applications built as AppKit heads, then the suites that run on a device.
/// Design: docs/design/tooling/tests.md
enum TestDiscovery {
    /// The hosts a package's folder name says it belongs to: `StateUI.AppKit`, `WebView.GTK`.
    static func host(of folder: URL) -> HostFamily? {
        let owner = folder.lastPathComponent == "Testing" ? folder.deletingLastPathComponent() : folder
        let suffix = owner.lastPathComponent.split(separator: ".").last.map(String.init) ?? ""
        return HostFamily.allCases.first { $0.folder == suffix }
    }

    /// The suites of `root` for `host`, `applications` its applications' package folders.
    static func suites(in root: URL, host: HostFamily?, applications: [URL]) -> [TestSuiteDescription] {
        let files = FileManager.default
        func children(_ folder: URL) -> [URL] {
            ((try? files.contentsOfDirectory(atPath: folder.path)) ?? []).sorted().map { folder.appendingPathComponent($0) }
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        }
        let owned = applications.map(\.standardizedFileURL.path).sorted()
        let grouped = [root.appendingPathComponent("lib"), root.appendingPathComponent("lib/StateUI")].flatMap(children)
        var seen = Set<String>()
        let packages = ([root] + grouped.flatMap { [$0, $0.appendingPathComponent("Testing")] } + owned.map { URL(fileURLWithPath: $0) })
            .filter { seen.insert($0.standardizedFileURL.path).inserted }
        var suites: [TestSuiteDescription] = []
        for folder in packages {
            guard let manifest = try? String(contentsOf: folder.appendingPathComponent("Package.swift"), encoding: .utf8),
                  manifest.contains(".testTarget(") else { continue }
            let id = folder.standardizedFileURL.path == root.standardizedFileURL.path ? root.lastPathComponent
                : String(folder.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            let uri = FileURI.string(folder)
            if let own = self.host(of: folder) {
                guard own == host else { continue }
                suites.append(TestSuiteDescription(
                    id: id, detail: "stateui repo test - the \(own.folder) host's tests, every verdict held, then its API records",
                    kind: .host, packageUri: uri, host: own))
            } else if host == .appkit, owned.contains(folder.standardizedFileURL.path) {
                suites.append(TestSuiteDescription(id: id, detail: "swift test as an AppKit build, on .build/appkit", kind: .package,
                                                   packageUri: uri, host: .appkit))
            } else {
                suites.append(TestSuiteDescription(id: id, detail: "swift test", kind: .package, packageUri: uri))
            }
        }
        for (device, folder, words) in [(HostFamily.android, "lib/StateUI/StateUI.Android/Tests", "the Android host's own tests on the device chosen, every verdict held, then its API record"),
                                        (.uikit, "lib/StateUI/StateUI.UIKit/Tests", "the UIKit host's own tests on the simulator chosen, every verdict held, then its API records")]
        where host == device && files.fileExists(atPath: root.appendingPathComponent("\(folder)/Package.swift").path) {
            suites.append(TestSuiteDescription(
                id: folder, detail: "stateui repo test - \(words)", kind: .host,
                packageUri: FileURI.string(root.appendingPathComponent(folder)), host: device, onDevice: true))
        }
        return suites
    }
}

/// One suite run as `TestDiscovery` describes it: a package's by `swift test` - an application built as an AppKit head
/// with `STATEUI_HOST=appkit` in `.build/appkit`, every other as plain Swift - a host's by its repository suite.
/// Design: docs/design/tooling/tests.md
struct TestRunner {
    let tools: ToolResolver

    /// Runs `suite`, a host's on `device` where it runs on one, the checkout's suites from `checkout`.
    func run(_ suite: TestSuiteDescription, device: String?, checkout: URL?, reporter: BuildReporter) async throws -> SuiteResult {
        if suite.kind == .host, let host = suite.host {
            guard let checkout else { throw ToolingError(.projectNotFound, "A host's suite runs in a StateUI checkout.") }
            let ran = try await HostSuite(checkout: checkout).run(host, device: device, reporter: reporter)
            return SuiteResult(suite: suite.id, phases: ran.phases)
        }
        let package = try FileURI.url(suite.packageUri)
        var environment = ProcessEnvironment.inherited.removing(
            "STATEUI_HOST", "STATEUI_UPDATE_EXPORTS", "STATEUI_UPDATE_DOCS", "STATEUI_UPDATE_SAMPLES", "STATEUI_STALE_ONLY")
        var arguments = ["test", "--package-path", package.path]
        if suite.host == .appkit {
            environment = environment.setting("STATEUI_HOST", to: "appkit")
            arguments += ["--scratch-path", package.appendingPathComponent(".build/appkit").path]
        }
        reporter.progress("testing \(suite.id)")
        let passed = try await TestRun.swift(tools.swift, arguments, environment, reporter)
        return SuiteResult(suite: suite.id, phases: [SuiteResult.Phase(name: "tests", passed: passed)])
    }
}
