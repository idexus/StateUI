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

    /// Runs the suite of `host` - `--filter`ed where given, a UIKit or Android one on the device `device` names - and
    /// answers each phase. An Android suite may instead be built alone for `architecture` (`buildOnly`), or run from
    /// the folder such a build made (`artifact`).
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a host whose suite has not moved to the tool.
    public func run(
        _ host: HostFamily, filter: String? = nil, device: String? = nil, buildOnly: Bool = false, architecture: Architecture? = nil,
        artifact: URL? = nil, reporter: BuildReporter = BuildReporter()
    ) async throws -> SuiteResult {
        guard [.appkit, .uikit, .android].contains(host) else {
            throw ToolingError(.invalidConfiguration, "\(host.rawValue)'s suite runs by its .scripts until its row moves to the tool.")
        }
        let lease = try await permit.acquire(for: "the \(host.folder) host's suite, stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        // Checked, never recorded: what writes marks and exports is asked by name (M11), never inherited.
        let checked = ProcessEnvironment.inherited.removing("STATEUI_UPDATE_EXPORTS", "STATEUI_UPDATE_DOCS", "STATEUI_STALE_ONLY", "STATEUI_FILTER")
        if buildOnly || artifact != nil, host != .android {
            throw ToolingError(.invalidConfiguration, "A suite is built alone, or run from what such a build made, for host:android.")
        }
        if host == .android {
            let destinations = self.destinations
            return try await AndroidSuite(
                checkout: checkout, tools: tools, android: AndroidTools(environment: environment), destinations: { await destinations(.android) }
            ).run(device: device, filter: filter, buildOnly: buildOnly, architecture: architecture, artifact: artifact,
                  environment: checked, reporter: reporter)
        }
        if host == .uikit {
            #if os(macOS)
            let destinations = self.destinations
            let phases = try await UIKitSuite(checkout: checkout, tools: tools, destinations: { await destinations(.uikit) })
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
        let modules = (await ToolOutput.text(tools.swift, ["build", "--package-path", package, "--show-bin-path"], environment: checked))?
            .split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        for module in ["StateUIAppKit", "StateUITesting"] {
            let environment = checked.removing("STATEUI_HOST").setting("STATEUI_API_MODULE", to: module)
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
        let outcome = try await ProcessRunner().run(
            ProcessRequest(tools.swift, arguments: arguments, environment: environment), output: reporter.output)
        try Task.checkCancellation()
        return outcome.succeeded
    }
}
