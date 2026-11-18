// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import StateUIToolingProtocol
import Synchronization

/// The UIKit host's suite: its tests an application of their own on a simulator - the simulator's accessibility on,
/// every conformance verdict held - then its facade and the testing module held to their API records for the
/// simulator's triple and SDK.
/// Design: docs/design/tooling/repository.md#the-uikit-hosts-suite
struct UIKitSuite {
    /// What the tests' application is - no application's `stateui.json`, the suite's own - at StateUI's release.
    static let identity = ApplicationFile(identifier: "com.stateui.uikit.tests", version: Release.version, build: 1)

    let checkout: URL
    let tools: ToolResolver
    /// Whether the API phase writes its records rather than holds them.
    var recordingAPI = false
    let destinations: @Sendable () async -> [Destination]

    func run(device: String?, filter: String?, environment: ProcessEnvironment, reporter: BuildReporter) async throws
        -> [SuiteResult.Phase] {
        let simulator = try AppleDestinations.choose(device, from: await destinations())
        guard simulator.kind == .simulator else {
            throw ToolingError(.invalidConfiguration, "The UIKit host's suite runs on a simulator; \(simulator.name) is a device.")
        }
        guard let sdk = await AppleSDK.find(.iOSSimulator),
              let platform = await ToolOutput.standardOutput(.name("xcrun"), ["--sdk", sdk.platform.rawValue, "--show-sdk-platform-path"])?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        else { throw ToolingError(.missingToolchain, "The selected Xcode holds no iphonesimulator SDK; `stateui doctor` says what to install.") }

        reporter.progress("booting \(simulator.name)")
        try await ToolStep.run(.name("xcrun"), ["simctl", "bootstatus", simulator.udid, "-b"], limit: .seconds(300))

        let package = checkout.appendingPathComponent("lib/StateUI/StateUI.UIKit/Tests")
        let product = "StateUIUIKitTests"
        let architecture = Architecture(rawValue: Machine.current.architecture) ?? .arm64
        let context = BuildContext(
            application: package, product: product, host: .uikit, configuration: .debug, architecture: architecture,
            compiler: (await ToolOutput.text(tools.swift, ["--version"]))?.split(separator: "\n").first.map(String.init) ?? "",
            sdk: sdk.identity, library: checkout)
        let triple = sdk.platform.triple(architecture, floor: Doctor.appleFloor)
        // XCTest is the simulator platform's own, read where it stands.
        let (frameworks, libraries) = ("\(platform)/Developer/Library/Frameworks", "\(platform)/Developer/usr/lib")
        let found = [("-F", frameworks), ("-I", libraries)].flatMap { ["-Xswiftc", $0.0, "-Xswiftc", $0.1] }
            + [("-F", frameworks), ("-L", libraries), ("-rpath", frameworks), ("-rpath", libraries)].flatMap { ["-Xlinker", $0.0, "-Xlinker", $0.1] }
        let common = ["--package-path", package.path, "--scratch-path", context.scratch.path, "--configuration", "debug",
                      "--triple", triple, "--sdk", sdk.path] + found
        reporter.progress("building the UIKit host's tests")
        let built = try await ProcessRunner().run(
            ProcessRequest(tools.swift, arguments: ["build", "--product", product] + common, environment: environment), output: reporter.output)
        try Task.checkCancellation()
        guard built.succeeded else { return [SuiteResult.Phase(name: "tests", passed: false)] }
        let binaries = try await ProductFolder.of(tools.swift, placing: common, environment: environment)

        let work = context.scratch.appendingPathComponent("stateui")
        let staging = work.appendingPathComponent("suite")
        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let bundle = try await UIKitBundle(
            application: package, name: product, product: product, binaries: binaries, identity: Self.identity,
            minimumSystem: Doctor.appleFloor, platform: .iOSSimulator, work: work).assemble(in: staging, signing: .adHoc)

        // The suite stands as a screen reader does: UIKit's accessibility answers for its controls as for a VoiceOver
        // user. Written after the build, so a simulator just booted for the first time has settled.
        // Design: docs/design/tooling/repository.md#the-uikit-hosts-suite
        reporter.progress("turning \(simulator.name)'s accessibility on")
        for key in ["ApplicationAccessibilityEnabled", "AccessibilityEnabled"] {
            try await ToolStep.run(
                .name("xcrun"), ["simctl", "spawn", simulator.udid, "defaults", "write", "com.apple.Accessibility", key, "-bool", "true"],
                limit: .seconds(300))
        }

        let summary = Summary()
        let launch = SimulatorLaunch(
            simulator: simulator, bundle: bundle, identifier: Self.identity.identifier,
            logs: work.appendingPathComponent("logs"),
            environment: HandedEnvironment(of: Self.launched(filter: filter, environment: environment)))
        let suite = BuildResult(
            application: product, host: .uikit, configuration: .debug, architecture: architecture,
            folderUri: FileURI.string(staging), programUri: FileURI.string(bundle.appendingPathComponent(product)),
            bundleUri: FileURI.string(bundle), destination: simulator)
        _ = try await launch.run(suite, held: false, reporter: RunReporter(build: reporter, output: { line in
            summary.read(line.text)
            reporter.output(line)
        }))
        // A filter that matched nothing proves nothing.
        var phases = [SuiteResult.Phase(name: "tests", passed: summary.passed && !(filter != nil && summary.ranNone))]

        reporter.progress("checking the API records")
        for module in ["StateUIUIKit", "StateUITesting"] {
            let held = environment.forAPIRecord(recording: recordingAPI).setting("STATEUI_API_MODULE", to: module)
                .setting("STATEUI_API_MODULES", to: binaries.path).setting("STATEUI_API_TRIPLE", to: triple)
                .setting("STATEUI_API_SDK", to: sdk.path).setting("STATEUI_API_ARGUMENTS", to: "")
            let outcome = try await ProcessRunner().run(
                ProcessRequest(tools.swift, arguments: [
                    "test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord",
                ], environment: held), output: reporter.output)
            try Task.checkCancellation()
            phases.append(SuiteResult.Phase(name: "api \(module)", passed: outcome.succeeded))
        }
        return phases
    }

    /// The test application's last word: `Executed N tests, with M failures`.
    final class Summary: Sendable {
        private let last = Mutex<String?>(nil)

        func read(_ line: String) {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.firstMatch(of: /^Executed \d+ tests?, with \d+ failures?/) != nil else { return }
            last.withLock { $0 = text }
        }

        /// Whether it said its tests ran with no failure.
        var passed: Bool { last.withLock { $0?.contains(" with 0 failures") ?? false } }

        /// Whether it said no test ran.
        var ranNone: Bool { last.withLock { $0?.hasPrefix("Executed 0 tests") ?? false } }
    }
}

extension UIKitSuite {
    /// What the test application is handed: the filter, and what a recording run asks of it.
    static func launched(filter: String?, environment: ProcessEnvironment) -> [String: String] {
        var handed = filter.map { ["STATEUI_FILTER": $0] } ?? [:]
        for name in ["STATEUI_UPDATE_EXPORTS", "STATEUI_STALE_ONLY"] {
            if let value = environment.set[name] { handed[name] = value }
        }
        return handed
    }
}
#endif
