// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What a guest has of what a head of its host needs: the way to it, checked from the Mac, then what its own stateui
/// finds in it. Changes nothing - neither starts the guest nor lays anything in it.
/// Design: docs/design/tooling/guests.md#the-doctor-of-a-guest
struct GuestDoctor: Sendable {
    let guests: ParallelsGuests

    /// The findings of `device`, a guest a head of `host` is built in, for the Mac's `folders` - the StateUI checkouts
    /// its tool is laid from - it is to reach.
    func check(host: HostFamily, device: String, folders: [URL]) async -> ToolchainReport {
        var findings: [ToolFinding] = []
        let finding = { (component: String, neededBy: String, found: String?, advice: String, machine: String?) in
            ToolFinding(component: component, neededBy: neededBy, hosts: [host], found: found, tooOld: nil, advice: advice,
                        machine: machine)
        }
        guard let prlctl = guests.prlctl else {
            return ToolchainReport(findings: [finding(
                "Parallels Desktop's prlctl", "a guest", nil,
                "Install Parallels Desktop Pro or Business: its prlctl reaches a guest.", nil)])
        }
        findings.append(finding("Parallels Desktop's prlctl", "a guest", prlctl.path, "", nil))

        let all = await guests.list()
        guard let guest = all.first(where: { $0.name == device || $0.id == device }) else {
            findings.append(finding(
                "the guest \(device)", host.folder, nil,
                "No guest named \(device) stands here: `stateui devices --host \(host.rawValue)` lists them.", device))
            return ToolchainReport(findings: findings)
        }
        let system = ParallelsGuests.system(for: host)
        let described = [guest.os, guest.architecture?.rawValue ?? "", guest.state].filter { !$0.isEmpty }.joined(separator: ", ")
        guard guest.system == system else {
            findings.append(finding(
                "the guest \(device)", host.folder, nil,
                "\(device) runs \(guest.os); a \(host.folder) head is built in a \(system == .windows ? "Windows" : "Linux") guest.",
                device))
            return ToolchainReport(findings: findings)
        }
        findings.append(finding("the guest \(device)", host.folder, described, "", device))
        findings.append(finding(
            "Parallels Tools", "prlctl exec and the shared folders", guest.hasTools ? "installed" : nil,
            "Install Parallels Tools in \(device) (Actions ▸ Install Parallels Tools).", device))
        for folder in folders {
            let share = guest.share(of: folder)
            findings.append(finding(
                "\(folder.lastPathComponent) shared", "laying the guest's stateui", share.map { "\(folder.path), through \($0)" },
                "Share \(folder.path) with \(device) - its Configuration ▸ Options ▸ Sharing - or every disk.", device))
        }
        guard guest.state == "running" else {
            findings.append(ToolFinding(
                component: "\(device) running", neededBy: "the checks inside it", hosts: [],
                found: "\(guest.state) - a build starts it; what stands inside it is checked once it runs", tooOld: nil,
                advice: "", machine: device))
            return ToolchainReport(findings: findings)
        }

        let commands = GuestCommands(prlctl: prlctl, guest: guest)
        guard await commands.userSession(), let places = await commands.places() else {
            findings.append(finding(
                "the user's desktop session", "a build and a run in the guest", nil,
                "Log in to \(device)'s desktop: the tool works there as its user, and a head opens its window there.", device))
            return ToolchainReport(findings: findings)
        }
        findings.append(finding("the user's desktop session", "a build and a run in the guest", "open", "", device))

        let served = await commands.served(places.tool, workspaceUri: FileURI.string(URL(fileURLWithPath: "/")))
        guard let info = try? await served.query("server/info", .object([:])).decode(ServerInfo.self) else {
            findings.append(finding(
                "stateui in the guest", "a build and a run in the guest", nil,
                "Lay it: `stateui guest prepare --device \"\(device)\"` builds it in the guest, at \(places.tool).", device))
            return ToolchainReport(findings: findings)
        }
        let speaks = info.apiVersions.contains { range in
            Release.apiVersions.contains { $0.major == range.major && $0.minMinor <= range.maxMinor && range.minMinor <= $0.maxMinor }
        }
        findings.append(ToolFinding(
            component: "stateui in the guest", neededBy: "a build and a run in the guest", hosts: [host],
            found: speaks ? "\(info.server.version) at \(places.tool)" : nil, tooOld: speaks ? nil : info.server.version,
            advice: "Lay it again: `stateui guest prepare --device \"\(device)\"`.", machine: device))
        guard speaks, let report = try? await served.query("toolchain/check", .object([:])).decode(ToolchainReport.self)
        else { return ToolchainReport(findings: findings) }
        return ToolchainReport(findings: findings + report.findings.map { var found = $0; found.machine = device; return found })
    }
}
