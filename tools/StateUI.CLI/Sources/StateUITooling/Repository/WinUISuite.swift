// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The WinUI host's suite on Windows: unfiltered, the foundation's own tests first - the branches no other machine
/// runs - then the host's Testing package, its runner made self-contained as an application is, every test in a
/// process of its own, the conformance families only where `--filter` names them; then the facade and the web view's
/// backend held to their API records.
/// Design: docs/design/tooling/repository.md#the-winui-hosts-suite
struct WinUISuite {
    let checkout: URL
    let tools: ToolResolver
    let packages: WinUIPackages

    /// The conformance suite, some fifteen minutes: run only where a filter names it.
    static let conformance = "WinUIConformanceTests"

    /// What `swift test` is told for `filter`: every test in a process of its own - WinUI keeps the GDI objects of
    /// every window a test closes, and a process holds only so many - and no conformance unless asked.
    static func narrowing(_ filter: String?) -> [String] {
        (filter.map { ["--filter", $0] } ?? ["--skip", conformance]) + ["--parallel", "--num-workers", "1"]
    }

    func run(filter: String?, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> [SuiteResult.Phase] {
        try await WinUIProjection(library: checkout, packages: packages).ready(reporter: reporter)
        var phases: [SuiteResult.Phase] = []
        if filter == nil {
            reporter.progress("testing the foundation on Windows")
            phases.append(SuiteResult.Phase(name: "foundation", passed: try await swift(
                ["test", "--package-path", checkout.path, "--filter", "StateUIFoundationTests"], environment, reporter)))
        }
        let testing = checkout.appendingPathComponent("lib/StateUI/StateUI.WinUI/Testing").path
        reporter.progress("building the WinUI host's tests")
        guard try await swift(["build", "--package-path", testing, "--build-tests"], environment, reporter) else {
            return phases + [SuiteResult.Phase(name: "tests", passed: false)]
        }
        let modules = (await ToolOutput.text(tools.swift, ["build", "--package-path", testing, "--show-bin-path"], environment: environment))?
            .split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let machine = Architecture(rawValue: Machine.current.architecture) ?? .arm64
        reporter.progress("laying the Windows App SDK beside the test runner")
        try await WinUIHead.makeSelfContained(
            URL(fileURLWithPath: modules), executables: ["StateUIWinUITests-test-runner.exe"], architecture: machine, machine: machine,
            dependencies: try await WinUIHead.resolvedDependencies(
                of: URL(fileURLWithPath: testing), scratch: [], compiler: tools.swift, environment: environment),
            packages: packages,
            compiler: try ApplicationBuilder.compilerPath(tools.swift), cache: URL(fileURLWithPath: modules).appendingPathComponent("swift-runtime"),
            reporter: reporter)
        reporter.progress("testing the WinUI host")
        phases.append(SuiteResult.Phase(name: "tests", passed: try await swift(
            ["test", "--package-path", testing, "--skip-build"] + Self.narrowing(filter), environment, reporter)))

        reporter.progress("checking the API records")
        let maps = ["StateUI/StateUI.WinUI/Sources/CStateUIWinUI/include", "Backends/WebView.WinUI/Relay/include", "StateUI/StateUI.Host/CStateUIHost"]
            .map { "-fmodule-map-file=\(checkout.appendingPathComponent("lib/\($0)/module.modulemap").path)" }
        let arguments = maps.flatMap { ["-Xcc", $0] }
        for module in ["StateUIWinUI", "StateUIWebViewWinUI"] {
            let held = environment.removing("STATEUI_HOST", "STATEUI_UPDATE_EXPORTS", "STATEUI_STALE_ONLY").setting("STATEUI_API_MODULE", to: module)
                .setting("STATEUI_API_MODULES", to: modules).setting("STATEUI_API_TRIPLE", to: "").setting("STATEUI_API_SDK", to: "")
                .setting("STATEUI_API_ARGUMENTS", to: arguments.joined(separator: "\n"))
            phases.append(SuiteResult.Phase(name: "api \(module)", passed: try await swift(
                ["test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord"], held, reporter)))
        }
        return phases
    }

    private func swift(_ arguments: [String], _ environment: ProcessEnvironment, _ reporter: BuildReporter) async throws -> Bool {
        try await TestRun.swift(tools.swift, arguments, environment, reporter)
    }
}
