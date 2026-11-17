// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What a machine paired with the project has of what a head of its host needs: its service answering and admitting
/// this machine, its stateui of this release, then what that stateui finds there. Changes nothing.
/// Design: docs/design/tooling/service.md#work-on-another-machine
struct RemoteDoctor: Sendable {
    /// The findings of `machine`, which a head of `host` is built on.
    func check(host: HostFamily, machine: RemoteMachine) async -> ToolchainReport {
        let finding = { (component: String, found: String?, advice: String) in
            ToolFinding(
                component: component, neededBy: "a build and a run on \(machine.name)", hosts: [host], found: found, tooOld: nil,
                advice: advice, machine: machine.name)
        }
        let service = "the service of \(machine.name)"
        let info: ServerInfo
        switch await ServiceProbe.check(machine) {
        case .admitted(let said):
            info = said
        case .notAdmitted(let why):
            return ToolchainReport(findings: [finding(
                service, nil, "It answers at \(machine.address):\(machine.port) but admits this machine not - pair again with the code it shows: `stateui remote add \(machine.name) \(machine.address):\(machine.port) --code <code>`. \(why)")])
        case .unreached(let why):
            return ToolchainReport(findings: [finding(
                service, nil, "None answers at \(machine.address):\(machine.port) - `stateui service install` on \(machine.name) starts it with its user's session. \(why)")])
        }
        var findings = [finding(service, "\(machine.address):\(machine.port), \(info.machine.system) \(info.machine.architecture)", "")]
        guard info.server.version == Release.version else {
            findings.append(finding(
                "stateui on \(machine.name)", info.server.version, "Lay stateui \(Release.version) there and start its service again: `stateui service restart`."))
            return ToolchainReport(findings: findings)
        }
        findings.append(finding("stateui on \(machine.name)", info.server.version, ""))
        let asked = try? await ServedTool(remote: machine, workspaceUri: "file:///")
            .query("toolchain/check", try JSONValue(encoding: ToolchainQuery(host: host))).decode(ToolchainReport.self)
        for var each in asked?.findings ?? [] {
            each.machine = machine.name
            findings.append(each)
        }
        return ToolchainReport(findings: findings)
    }
}
