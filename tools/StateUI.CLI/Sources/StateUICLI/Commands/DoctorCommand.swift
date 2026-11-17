// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui doctor`: what this machine has of everything it needs, and what to install.
struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Checks this machine - or a guest of it - for what each host needs, and says what to install. Changes nothing."
    )

    @Option(help: "Fail only on what this host needs: appkit, uikit, android, winui, gtk or web.")
    var host: HostFamily?

    @Option(help: "A guest of this Mac a GTK or WinUI head is built in, as `stateui devices` names it: check it instead.")
    var device: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        if device != nil, host == nil { throw ValidationError("A guest is checked for a host: name it with --host gtk or --host winui.") }
        let project = FileURI.string(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let report = await ToolingService().checkToolchain(ToolchainQuery(host: host, device: device, projectUri: project))
        try output.format.write(report, text: Self.words)
        if report.lacks(for: host) { throw ExitCode(ExitStatus.missingPrerequisite) }
    }

    /// A line a component: found, too old or missing, who needs it, and for what is not found, how to get it.
    static func words(_ report: ToolchainReport) -> String {
        var machine: String?? = .none
        return report.findings.flatMap { finding -> [String] in
            let heading = machine.map { $0 != finding.machine } ?? (finding.machine != nil)
                ? ["\(finding.machine ?? "This machine"):"] : []
            machine = .some(finding.machine)
            if let found = finding.found { return heading + ["✓ \(finding.component) - \(found) [\(finding.neededBy)]"] }
            let state = finding.tooOld.map { "\($0) found, too old" } ?? "not found"
            return heading + ["✗ \(finding.component) - \(state) [\(finding.neededBy)]. \(finding.advice)"]
        }.joined(separator: "\n")
    }
}

extension HostFamily: ExpressibleByArgument {}
