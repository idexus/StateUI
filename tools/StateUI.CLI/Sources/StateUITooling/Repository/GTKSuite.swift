// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The GTK host's suite on Linux: unfiltered, the foundation's own tests first - the C library's Glibc branches no
/// other machine runs - then the host's Testing package, every verdict held, then the facade and the web view's
/// backend held to their API records, their C modules found by their maps and pkg-config's flags.
/// Design: docs/design/tooling/repository.md#the-gtk-hosts-suite
struct GTKSuite {
    let checkout: URL
    let tools: ToolResolver

    func run(filter: String?, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> [SuiteResult.Phase] {
        // Every machine meets one desktop: a user who chose the accent, as GNOME's from 47 on.
        let desktop = environment.setting("ADW_DEBUG_ACCENT_COLOR", to: "blue")
        var phases: [SuiteResult.Phase] = []
        if filter == nil {
            reporter.progress("testing the foundation on Linux")
            phases.append(SuiteResult.Phase(name: "foundation", passed: try await swift(
                ["test", "--package-path", checkout.path, "--filter", "StateUIFoundationTests"], desktop, reporter)))
        }
        let testing = checkout.appendingPathComponent("lib/StateUI/StateUI.GTK/Testing").path
        reporter.progress("testing the GTK host")
        phases.append(SuiteResult.Phase(name: "tests", passed: try await swift(
            ["test", "--package-path", testing] + (filter.map { ["--filter", $0] } ?? []), desktop, reporter)))

        reporter.progress("checking the API records")
        let modules = (await ToolOutput.text(tools.swift, ["build", "--package-path", testing, "--show-bin-path"], environment: environment))?
            .split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let maps = ["StateUI/StateUI.GTK/Sources/CStateUIGTK", "StateUI/StateUI.GTK/Sources/CStateUISoup", "StateUI/StateUI.Host/CStateUIHost",
                    "Backends/WebView.GTK/Sources/CWebKitGTK"]
            .map { "-fmodule-map-file=\(checkout.path)/lib/\($0)/module.modulemap" }
        let flags = (await ToolOutput.standardOutput(.name("pkg-config"), ["--cflags", "libadwaita-1", "libsoup-3.0", "webkitgtk-6.0"]) ?? "")
            .split(whereSeparator: \.isWhitespace).map(String.init)
        let arguments = (maps + flags).flatMap { ["-Xcc", $0] }
        for module in ["StateUIGTK", "StateUIWebViewGTK"] {
            let held = environment.removing("STATEUI_HOST").setting("STATEUI_API_MODULE", to: module)
                .setting("STATEUI_API_MODULES", to: modules).setting("STATEUI_API_TRIPLE", to: "").setting("STATEUI_API_SDK", to: "")
                .setting("STATEUI_API_ARGUMENTS", to: arguments.joined(separator: "\n"))
            phases.append(SuiteResult.Phase(name: "api \(module)", passed: try await swift(
                ["test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord"], held, reporter)))
        }
        return phases
    }

    private func swift(_ arguments: [String], _ environment: ProcessEnvironment, _ reporter: BuildReporter) async throws -> Bool {
        let outcome = try await ProcessRunner().run(ProcessRequest(tools.swift, arguments: arguments, environment: environment), output: reporter.output)
        try Task.checkCancellation()
        return outcome.succeeded
    }
}
