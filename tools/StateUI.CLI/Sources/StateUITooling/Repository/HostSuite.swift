// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A host's own suite, run in a StateUI checkout as the host's CI runs it: the host's tests with every conformance
/// family held to its recorded marks - nothing written - then the host's facade and the testing module held to
/// their API records.
/// Design: docs/design/tooling/repository.md#a-hosts-suite
public struct HostSuite: Sendable {
    private let checkout: URL
    private let permit: BuildPermit
    private let tools: ToolResolver
    private let destinations: @Sendable (HostFamily) async -> [Destination]
    private let environment: [String: String]

    /// The suites of the checkout at `checkout`, a UIKit or Android suite's device chosen among those `destinations`
    /// lists for its host.
    public init(
        checkout: URL, environment: [String: String] = ProcessInfo.processInfo.environment, permit: BuildPermit = BuildPermit(),
        destinations: @escaping @Sendable (HostFamily) async -> [Destination] = { host in
            host == .android ? await AndroidDestinations().list() : await AppleDestinations().list()
        }
    ) {
        self.checkout = checkout
        self.permit = permit
        self.destinations = destinations
        self.environment = environment
        tools = ToolResolver(environment: environment)
    }

    /// Holds the library's public surfaces to `lib/StateUI/exports/api` - what an application writes and what an
    /// extension writes - or writes them there where `recording`.
    public func runLibraryAPI(recording: Bool, reporter: BuildReporter = BuildReporter()) async throws -> SuiteResult {
        reporter.progress(recording ? "recording the library's API" : "checking the library's API")
        let environment = ProcessEnvironment.inherited.forAPIRecord(recording: recording)
            .removing("STATEUI_API_MODULE", "STATEUI_API_MODULES", "STATEUI_API_ARGUMENTS")
        let held = try await TestRun.swift(tools.swift, ["test", "--package-path", checkout.path, "--filter", "APISurfaceTests"], environment, reporter)
        return SuiteResult(suite: "api:StateUI", phases: [SuiteResult.Phase(name: recording ? "api StateUI recorded" : "api StateUI", passed: held)])
    }

    /// Runs the suite of `host` - `--filter`ed where given, a UIKit or Android one on the device `device` names - and
    /// answers each phase. An Android suite may instead be built alone for `architecture` (`buildOnly`), or run from
    /// the folder such a build made (`artifact`).
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a host whose suite has not moved to the tool.
    ///
    /// A conformance run may record what it proves instead (`recording`): each family's verdicts written, at the
    /// revision `revisions` gives a run on a device that reads no repository - and only the stale families
    /// (`staleOnly`), where the host's own driver reads the repository to tell them.
    public func run(
        _ host: HostFamily, filter: String? = nil, device: String? = nil, buildOnly: Bool = false, architecture: Architecture? = nil,
        artifact: URL? = nil, recording: Bool = false, staleOnly: Bool = false, revisions: [String: String] = [:],
        recordingAPI: Bool = false, reporter: BuildReporter = BuildReporter()
    ) async throws -> SuiteResult {
        let lease = try await permit.acquire(for: "the \(host.folder) host's suite, stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        // What writes marks and exports is asked by name, never inherited; an API phase never records.
        var checked = ProcessEnvironment.inherited.removing("STATEUI_UPDATE_EXPORTS", "STATEUI_UPDATE_DOCS", "STATEUI_STALE_ONLY", "STATEUI_FILTER")
        if recording { checked = checked.setting("STATEUI_UPDATE_EXPORTS", to: "1") }
        if staleOnly { checked = checked.setting("STATEUI_STALE_ONLY", to: "1") }
        if buildOnly || artifact != nil, host != .android {
            throw ToolingError(.invalidConfiguration, "A suite is built alone, or run from what such a build made, for host:android.")
        }
        if host == .web {
            #if os(macOS) || os(Linux)
            let phases = try await WebSuite(checkout: checkout, tools: tools, recordingAPI: recordingAPI).run(filter: filter, environment: checked, reporter: reporter)
            return SuiteResult(suite: "host:web", phases: phases)
            #else
            throw ToolingError(.invalidConfiguration, "The Web host's suite runs on macOS and Linux.")
            #endif
        }
        if host == .winui {
            #if os(Windows)
            let phases = try await WinUISuite(checkout: checkout, tools: tools, recordingAPI: recordingAPI, packages: WinUIPackages(environment: environment))
                .run(filter: filter, environment: checked, reporter: reporter)
            return SuiteResult(suite: "host:winui", phases: phases)
            #else
            throw ToolingError(.invalidConfiguration, "The WinUI host's suite runs on Windows.")
            #endif
        }
        if host == .gtk {
            #if os(Linux)
            let phases = try await GTKSuite(checkout: checkout, tools: tools, recordingAPI: recordingAPI).run(filter: filter, environment: checked, reporter: reporter)
            return SuiteResult(suite: "host:gtk", phases: phases)
            #else
            throw ToolingError(.invalidConfiguration, "The GTK host's suite runs on Linux.")
            #endif
        }
        if host == .android {
            let destinations = self.destinations
            return try await AndroidSuite(
                checkout: checkout, tools: tools, recordingAPI: recordingAPI, android: AndroidTools(environment: environment),
                destinations: { await destinations(.android) }
            ).run(device: device, filter: filter, buildOnly: buildOnly, architecture: architecture, artifact: artifact,
                  recording: recording ? revisions : nil, environment: checked, reporter: reporter)
        }
        if host == .uikit {
            #if os(macOS)
            let destinations = self.destinations
            let phases = try await UIKitSuite(checkout: checkout, tools: tools, recordingAPI: recordingAPI, destinations: { await destinations(.uikit) })
                .run(device: device, filter: filter, environment: checked, reporter: reporter)
            return SuiteResult(suite: "host:uikit", phases: phases)
            #else
            throw ToolingError(.invalidConfiguration, "The UIKit host's suite runs on a Mac.")
            #endif
        }
        let package = checkout.appendingPathComponent("lib/StateUI/StateUI.AppKit").path
        reporter.progress("testing the AppKit host")
        let tests = try await run(["test", "--package-path", package] + (filter.map { ["--filter", $0] } ?? []), checked, reporter)
        var phases = [SuiteResult.Phase(name: "tests", passed: tests)]

        reporter.progress("checking the API records")
        let modules = try await ProductFolder.of(tools.swift, placing: ["--package-path", package], environment: checked).path
        for module in ["StateUIAppKit", "StateUITesting"] {
            let environment = checked.forAPIRecord(recording: recordingAPI).setting("STATEUI_API_MODULE", to: module)
                .setting("STATEUI_API_MODULES", to: modules).setting("STATEUI_API_TRIPLE", to: "").setting("STATEUI_API_SDK", to: "")
                .setting("STATEUI_API_ARGUMENTS", to: "")
            let held = try await run(
                ["test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord"],
                environment, reporter)
            phases.append(SuiteResult.Phase(name: "api \(module)", passed: held))
        }
        return SuiteResult(suite: "host:\(host.rawValue)", phases: phases)
    }

    private func run(_ arguments: [String], _ environment: ProcessEnvironment, _ reporter: BuildReporter) async throws -> Bool {
        try await TestRun.swift(tools.swift, arguments, environment, reporter)
    }
}
