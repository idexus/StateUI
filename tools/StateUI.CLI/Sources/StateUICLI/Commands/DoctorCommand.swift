// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import StateUITooling
import StateUIToolingProtocol

/// `stateui doctor`: what this machine has of everything it needs, and what to install.
struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Checks this machine for what each host needs, and says what to install. Changes nothing."
    )

    @Option(help: "Fail only on what this host needs: appkit, uikit, android, winui, gtk or web.")
    var host: HostFamily?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let report = await ToolingService().checkToolchain()
        try output.format.write(report, text: Self.words)
        if report.lacks(for: host) { throw ExitCode(ExitStatus.missingPrerequisite) }
    }

    /// A line a component: found, too old or missing, who needs it, and for what is not found, how to get it.
    static func words(_ report: ToolchainReport) -> String {
        report.findings.map { finding in
            if let found = finding.found { return "✓ \(finding.component) - \(found) [\(finding.neededBy)]" }
            let state = finding.tooOld.map { "\($0) found, too old" } ?? "not found"
            return "✗ \(finding.component) - \(state) [\(finding.neededBy)]. \(finding.advice)"
        }.joined(separator: "\n")
    }
}

extension HostFamily: ExpressibleByArgument {}
