// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Where a host's conformance verdicts stand, as the library itself reads them: its helper
/// `stateui-conformance-metadata` (`lib/StateUI/StateUI.Conformance`), built with SwiftPM and run - never a second
/// reader of a revision.
/// Design: docs/design/tooling/repository.md#a-familys-revision
struct ConformanceMetadata {
    let checkout: URL
    let tools: ToolResolver

    private var package: String { checkout.appendingPathComponent("lib/StateUI/StateUI.Conformance").path }

    /// `host`'s families, after the helper is built where it changed.
    func status(of host: HostFamily, reporter: BuildReporter) async throws -> ConformanceStatus {
        let program = try await helper(reporter: reporter)
        let said = Gathered()
        let outcome = try await ProcessRunner().run(
            ProcessRequest(.path(program.path), arguments: ["--repository", checkout.path, "--host", host.rawValue, "--format", "json"]),
            output: said.add)
        let json = said.lines(of: .standardOutput).joined(separator: "\n")
        guard outcome.succeeded, let status = try? JSONDecoder().decode(ConformanceStatus.self, from: Data(json.utf8)) else {
            throw ToolingError(.toolFailed, "stateui-conformance-metadata did not say where \(host.rawValue)'s verdicts stand: \(said.lines(of: .standardError).suffix(3).joined(separator: " "))")
        }
        return status
    }

    /// The helper's program, built first.
    private func helper(reporter: BuildReporter) async throws -> URL {
        reporter.progress("building stateui-conformance-metadata")
        let built = try await ProcessRunner().run(
            ProcessRequest(tools.swift, arguments: ["build", "--package-path", package, "--product", "stateui-conformance-metadata"],
                           environment: ProcessEnvironment.inherited.removing("STATEUI_HOST")),
            output: reporter.output)
        guard built.succeeded,
              let folder = (await ToolOutput.text(tools.swift, ["build", "--package-path", package, "--show-bin-path"],
                                                  environment: ProcessEnvironment.inherited.removing("STATEUI_HOST")))?
                .split(separator: "\n").last.map({ String($0).trimmingCharacters(in: .whitespaces) })
        else { throw ToolingError(.toolFailed, "stateui-conformance-metadata did not build.") }
        #if os(Windows)
        return URL(fileURLWithPath: folder).appendingPathComponent("stateui-conformance-metadata.exe")
        #else
        return URL(fileURLWithPath: folder).appendingPathComponent("stateui-conformance-metadata")
        #endif
    }
}
