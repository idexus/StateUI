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

    /// The suites of the checkout at `checkout`.
    public init(checkout: URL, environment: [String: String] = ProcessInfo.processInfo.environment, permit: BuildPermit = BuildPermit()) {
        self.checkout = checkout
        self.permit = permit
        tools = ToolResolver(environment: environment)
    }

    /// Runs the suite of `host` - `--filter`ed where given - and answers each phase.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a host whose suite has not moved to the tool.
    public func run(_ host: HostFamily, filter: String? = nil, reporter: BuildReporter = BuildReporter()) async throws -> SuiteResult {
        guard host == .appkit else {
            throw ToolingError(.invalidConfiguration, "\(host.rawValue)'s suite runs by its .scripts until its row moves to the tool.")
        }
        let package = checkout.appendingPathComponent("lib/StateUI/StateUI.AppKit").path
        let lease = try await permit.acquire(for: "the AppKit host's suite, stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        // Checked, never recorded: what writes marks and exports is asked by name (M11), never inherited.
        let checked = ProcessEnvironment.inherited.removing("STATEUI_UPDATE_EXPORTS", "STATEUI_UPDATE_DOCS", "STATEUI_STALE_ONLY", "STATEUI_FILTER")
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
