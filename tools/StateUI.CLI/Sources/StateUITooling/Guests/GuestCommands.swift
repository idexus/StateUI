// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What the tool runs in a guest through `prlctl exec`, as its user - who is logged in to its desktop.
/// Design: docs/design/tooling/guests.md#reaching-a-guest
struct GuestCommands: Sendable {
    let prlctl: URL
    let guest: ParallelsGuests.Guest

    /// What `program`, run with `arguments` in the guest as its user, wrote, and whether it ended well. A job Parallels
    /// lost before running it is asked again, up to five times.
    func run(_ program: String, _ arguments: [String] = []) async -> (succeeded: Bool, output: String) {
        let ran = await status(program, arguments)
        return (ran.status == 0, ran.output)
    }

    /// What `program`, run with `arguments` in the guest as its user, wrote - each line told to `output` as it comes -
    /// and the status it ended with, nil where it did not end by itself. A job Parallels lost before running it is
    /// asked again, up to five times.
    func status(
        _ program: String, _ arguments: [String], timeout: Duration = .seconds(120),
        output: @escaping @Sendable (ProcessOutput) -> Void = { _ in }
    ) async -> (status: Int?, output: String) {
        let program = await located(program)
        for attempt in 1...5 {
            let said = Gathered()
            let outcome = try? await ProcessRunner().run(
                ProcessRequest(.path(prlctl.path), arguments: ["exec", guest.id, "--current-user", program] + arguments,
                               timeout: timeout),
                output: { line in said.add(line); output(line) })
            let text = (said.lines(of: .standardOutput) + said.lines(of: .standardError)).joined(separator: "\n")
            if text.contains("PrlJob_GetResult") || text.contains("PrlJob_GetRetCode"), attempt < 5 {
                try? await Task.sleep(for: .seconds(3))
                continue
            }
            guard let outcome, outcome.stop == nil, case .exited(let code) = outcome.termination else { return (nil, text) }
            return (code, text)
        }
        return (nil, "")
    }

    /// What `program`, run with `arguments` in the guest by its system - Parallels Tools' own account, with no user's
    /// session and no prompt - wrote, and the status it ended with: what only the machine's owner may change.
    func asSystem(_ program: String, _ arguments: [String]) async -> (status: Int?, output: String) {
        let said = Gathered()
        let outcome = try? await ProcessRunner().run(
            ProcessRequest(.path(prlctl.path), arguments: ["exec", guest.id, program] + arguments, timeout: .seconds(120)),
            output: said.add)
        let text = (said.lines(of: .standardOutput) + said.lines(of: .standardError)).joined(separator: "\n")
        guard let outcome, outcome.stop == nil, case .exited(let code) = outcome.termination else { return (nil, text) }
        return (code, text)
    }

    /// `program` as `prlctl exec` finds it: on Windows, where it searches no user's path, by its whole path, which
    /// `where.exe` - of the system's own folder - gives; elsewhere as named.
    private func located(_ program: String) async -> String {
        guard guest.system == .windows, !program.contains("\\"), program != "where.exe" else { return program }
        let found = await status("where.exe", [program]).output.split(whereSeparator: \.isNewline).first
        return found.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 } ?? program
    }

    /// The search path the user's login shell sets in a Linux guest - where swiftly puts Swift; nil on Windows, whose
    /// programs stand on the path `prlctl exec` hands them.
    func loginPath() async -> String? {
        guard guest.system == .linux else { return nil }
        let line = await run("bash", ["-l", "-c", "env"]).output.split(whereSeparator: \.isNewline).first { $0.hasPrefix("PATH=") }
        return line.map { String($0.dropFirst("PATH=".count)) }
    }

    /// Whether the guest's user is logged in to its desktop: Parallels runs nothing as a user who is not.
    func userSession() async -> Bool {
        await run(guest.system == .windows ? "whoami" : "id").succeeded
    }

    /// Where the tool keeps what it lays in the guest, under its user's home; nil where the guest does not say.
    func places() async -> WorkPlaces? {
        let asked = guest.system == .windows
            ? await run("powershell", ["-NoProfile", "-Command", "$HOME"]) : await run("printenv", ["HOME"])
        let home = asked.output.split(whereSeparator: \.isNewline).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return asked.succeeded && !home.isEmpty ? WorkPlaces(home: home, windows: guest.system == .windows) : nil
    }

    /// What a Linux guest's program needs of its user's environment beyond what `prlctl exec` hands it: the login
    /// shell's search path, and the desktop session's display, bus and runtime folder, which a head's window and its
    /// tests need; as `name=value`, none on Windows, whose programs run in the user's session already.
    func sessionEnvironment() async -> [String] {
        guard guest.system == .linux else { return [] }
        let user = await run("id", ["-u"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtime = "XDG_RUNTIME_DIR=/run/user/\(user)"
        let shown = await run("env", [runtime, "systemctl", "--user", "show-environment"]).output
        let session = shown.split(whereSeparator: \.isNewline).map(String.init).filter { line in
            ["DISPLAY=", "WAYLAND_DISPLAY=", "XAUTHORITY=", "DBUS_SESSION_BUS_ADDRESS=", "XDG_SESSION_TYPE="].contains { line.hasPrefix($0) }
        }
        return (await loginPath()).map { ["PATH=\($0)"] }.map { $0 + [runtime] + session } ?? [runtime] + session
    }

    /// The guest's stateui at `program`, served over `prlctl exec`'s standard streams, in its user's environment.
    func served(_ program: String, workspaceUri: String) async -> ServedTool {
        let environment = await sessionEnvironment()
        let started = environment.isEmpty ? [program] : ["env"] + environment + [program]
        return ServedTool(
            executable: .path(prlctl.path), arguments: ["exec", guest.id, "--current-user"] + started + ["serve", "--stdio"],
            workspaceUri: workspaceUri)
    }
}
