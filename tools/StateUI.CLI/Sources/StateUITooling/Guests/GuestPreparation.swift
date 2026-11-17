// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Lays a guest's own stateui: the checkout's `tools/StateUI.CLI` copied from the folder the guest shares into
/// `stateui-guest/tool`, built for release by the guest's Swift, and its program put in `stateui-guest/bin` - each
/// step a program of the guest's system, never a script - the sources it was built from remembered on the Mac.
/// Design: docs/design/tooling/guests.md#laying-the-guests-tool
struct GuestPreparation: Sendable {
    let commands: GuestCommands
    /// Where the Mac remembers, guest by guest, the sources each guest's stateui was last laid from.
    var stamps: URL = BuildPermit.userFolder.appendingPathComponent("guests")

    /// The sources of `checkout`'s tool, as one fingerprint: every file's path and bytes, but for what a build makes.
    static func sources(of checkout: URL) -> String {
        let tool = checkout.appendingPathComponent("tools/StateUI.CLI")
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ bytes: some Sequence<UInt8>) {
            for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
            hash = (hash ^ 0xff) &* 0x0000_0100_0000_01b3
        }
        for path in ((try? FolderFiles.every(under: tool)) ?? []).sorted() {
            mix(path.utf8)
            mix((try? Data(contentsOf: tool.appendingPathComponent(path))) ?? Data())
        }
        return String(hash, radix: 16)
    }

    /// The fingerprint of the sources the guest's stateui was last laid from, as the Mac remembers it.
    func laidSources() -> String? {
        try? String(contentsOf: stamps.appendingPathComponent("\(commands.guest.id).tool"), encoding: .utf8)
    }

    /// Lays the stateui of `checkout` in the guest; the program's path there.
    func lay(checkout: URL, reporter: BuildReporter) async throws -> String {
        let guest = commands.guest
        guard let places = await commands.places() else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs nothing as its user: log in to its desktop.")
        }
        let tool = checkout.appendingPathComponent("tools/StateUI.CLI")
        guard let source = guest.path(of: tool) else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) reaches no \(checkout.path): share it with the guest.")
        }
        let windows = guest.system == .windows
        let copy = places.join(places.root, "tool", "StateUI.CLI")
        let bin = places.join(places.root, "bin")
        let path = await commands.loginPath()
        let swift = { (arguments: [String]) in path.map { ("env", ["PATH=\($0)", "swift"] + arguments) } ?? ("swift", arguments) }

        reporter.progress("copying the tool's sources into \(guest.name)")
        if !windows { _ = await commands.run("mkdir", ["-p", copy]) }
        let copied = windows
            ? await commands.status("robocopy", [source, copy, "/MIR", "/XD", ".build", ".swiftpm", "/NFL", "/NDL", "/NJH", "/NJS"])
            : await commands.status("rsync", ["-a", "--delete", "--exclude", ".build", "--exclude", ".swiftpm", source + "/", copy + "/"])
        guard let status = copied.status, windows ? status < 8 : status == 0 else {
            throw ToolingError(.toolFailed, "The tool's sources were not copied into \(guest.name):\n\(Self.last(copied.output))")
        }

        reporter.progress("building the tool in \(guest.name)")
        let build = swift(["build", "-c", "release", "--package-path", copy, "--product", "stateui"])
        let built = await commands.status(build.0, build.1, timeout: .seconds(1800), output: reporter.output)
        guard built.status == 0 else {
            throw ToolingError(.toolFailed, "The tool did not build in \(guest.name):\n\(Self.last(built.output))")
        }
        let shown = swift(["build", "-c", "release", "--package-path", copy, "--show-bin-path"])
        guard let products = await commands.run(shown.0, shown.1).output.split(whereSeparator: \.isNewline).last
            .map({ $0.trimmingCharacters(in: .whitespaces) }), !products.isEmpty
        else { throw ToolingError(.toolFailed, "SwiftPM did not say where it laid the tool in \(guest.name).") }

        reporter.progress("laying the tool in \(places.tool)")
        // Windows holds a running program's file: the guest's service, of the tool laid before, ends first.
        if windows { _ = await commands.run("taskkill", ["/F", "/IM", "stateui.exe"]) }
        let laid = windows
            ? await commands.status("robocopy", [products, bin, "stateui.exe", "*.dll", "/NFL", "/NDL", "/NJH", "/NJS"])
            : await commands.status("install", ["-D", "-m", "755", products + "/stateui", places.tool])
        guard let status = laid.status, windows ? status < 8 : status == 0 else {
            throw ToolingError(.toolFailed, "The tool was not laid in \(guest.name):\n\(Self.last(laid.output))")
        }
        reporter.progress("linking it as the stateui of \(guest.name)'s terminals")
        if !windows { _ = await commands.run("mkdir", ["-p", places.join(places.home, ".local", "bin")]) }
        let linked = windows
            ? await commands.run("powershell", ["-NoProfile", "-EncodedCommand", ServiceAutostart.encoded(Self.pathScript(bin: bin))])
            : await commands.run("ln", ["-sfn", places.tool, places.join(places.home, ".local", "bin", "stateui")])
        guard linked.succeeded else {
            throw ToolingError(.toolFailed, "The tool was not linked as \(guest.name)'s stateui:\n\(Self.last(linked.output))")
        }
        // A service laid in the guest runs the tool laid now: Windows ended it to lay the file, Linux runs the old one.
        let session = await commands.sessionEnvironment()
        let restart = session.isEmpty ? (places.tool, ["service", "restart"]) : ("env", session + [places.tool, "service", "restart"])
        _ = await commands.status(restart.0, restart.1, timeout: .seconds(60))
        try? FileManager.default.createDirectory(at: stamps, withIntermediateDirectories: true)
        try? Self.sources(of: checkout).write(to: stamps.appendingPathComponent("\(guest.id).tool"), atomically: true, encoding: .utf8)
        return places.tool
    }

    /// The PowerShell that puts `bin` first in the user's search path on Windows - each new terminal told - so `stateui`
    /// there is the one laid.
    static func pathScript(bin: String) -> String {
        """
        $bin = '\(bin)'
        $parts = @(([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') | Where-Object { $_ -and $_ -ne $bin })
        [Environment]::SetEnvironmentVariable('Path', ((@($bin) + $parts) -join ';'), 'User')
        """
    }

    private static func last(_ output: String) -> String {
        output.split(whereSeparator: \.isNewline).suffix(12).joined(separator: "\n")
    }
}
