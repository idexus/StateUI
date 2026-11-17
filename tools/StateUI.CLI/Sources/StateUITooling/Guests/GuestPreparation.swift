// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Lays a guest's own stateui: the checkout's `tools/StateUI.CLI` copied from the folder the guest shares into
/// `stateui-guest/tool`, built for release by the guest's Swift, and its program put in `stateui-guest/bin` - each
/// step a program of the guest's system, never a script.
/// Design: docs/design/tooling/guests.md#laying-the-guests-tool
struct GuestPreparation: Sendable {
    let commands: GuestCommands

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
        let laid = windows
            ? await commands.status("robocopy", [products, bin, "stateui.exe", "*.dll", "/NFL", "/NDL", "/NJH", "/NJS"])
            : await commands.status("install", ["-D", "-m", "755", products + "/stateui", places.tool])
        guard let status = laid.status, windows ? status < 8 : status == 0 else {
            throw ToolingError(.toolFailed, "The tool was not laid in \(guest.name):\n\(Self.last(laid.output))")
        }
        return places.tool
    }

    private static func last(_ output: String) -> String {
        output.split(whereSeparator: \.isNewline).suffix(12).joined(separator: "\n")
    }
}
