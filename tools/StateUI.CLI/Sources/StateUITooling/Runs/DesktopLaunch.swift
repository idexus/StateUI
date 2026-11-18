// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A GTK or WinUI head of this machine started from its program and followed until it ends, its output told as it
/// comes - here, or on another machine asking it. A GTK head is installed first and a copy of it running stopped: a GTK
/// application is one instance; under gdb, each GTK critical's stack and a crash's are said as they come. Cancelled,
/// the program is stopped with everything it started.
/// Design: docs/design/tooling/runs.md#a-desktop-head
struct DesktopLaunch: Sendable {
    /// Readies `built`'s program to start: a GTK head installed for the user, a copy of it running stopped.
    static func ready(_ built: BuildResult) async throws {
        guard built.host == .gtk else { return }
        let program = try FileURI.url(built.programUri)
        _ = try await ApplicationInstaller().install(try FileURI.url(built.folderUri))
        _ = try? await ProcessRunner().run(ProcessRequest(.name("pkill"), arguments: ["-f", "^\(program.path)( |$)"]))
    }

    /// Runs `built`'s program - a GTK head's under gdb where `underGDB`, held by `lldb-server` for LLDB where `held` -
    /// and follows it.
    func run(_ built: BuildResult, underGDB: Bool = false, held: Bool = false, reporter: RunReporter) async throws -> RunResult {
        let program = try FileURI.url(built.programUri)
        try await Self.ready(built)
        if held { return try await self.held(built, program: program, reporter: reporter) }
        let commands = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-gdb-\(UUID().uuidString).cmd")
        defer { try? FileManager.default.removeItem(at: commands) }
        if underGDB { try Data(GTKHead.gdbCommands(for: built.architecture).utf8).write(to: commands) }
        reporter.started(LaunchedApplication(build: built, process: nil, held: false))
        let said = reporter.output
        let outcome = try await ProcessRunner().run(
            Self.request(program, gdbCommands: underGDB ? commands : nil), output: { line in if !underGDB || !Self.gdbNoise(line.text) { said(line) } })
        try Task.checkCancellation()
        return RunResult(launched: LaunchedApplication(build: built, process: nil, held: false), exitStatus: Int(outcome.exitStatus))
    }

    /// `program` held by the toolchain's `lldb-server` on a free port of the loopback until LLDB connects, the way
    /// said as it starts; the port held for a relay while it runs.
    private func held(_ built: BuildResult, program: URL, reporter: RunReporter) async throws -> RunResult {
        guard let server = ToolResolver().lldbServer else {
            throw ToolingError(.missingToolchain, "lldb-server is not here: it comes with the Swift toolchain, beside swift.")
        }
        let port = try DebugPorts.free()
        return try await DebugPorts.holding(port) {
            let launched = LaunchedApplication(
                build: built, process: nil, held: true, debugger: DebugDescriptors.gdbServer(program: program, port: port))
            reporter.started(launched)
            let outcome = try await ProcessRunner().run(
                ProcessRequest(.path(server.path), arguments: ["gdbserver", "127.0.0.1:\(port)", "--", program.path]), output: reporter.output)
            try Task.checkCancellation()
            return RunResult(launched: launched, exitStatus: Int(outcome.exitStatus))
        }
    }

    /// Whether gdb's `line` is its word on a Clang module's debug information, which it cannot read as split DWARF.
    static func gdbNoise(_ line: String) -> Bool {
        line.hasPrefix("During symbol reading: Could not find DWO CU ") && line.contains(".pcm(")
    }

    /// What starts `program`: itself, or gdb running it with the commands in `gdbCommands` - Swift's own backtrace off,
    /// as gdb tells the stack.
    static func request(_ program: URL, gdbCommands: URL?) -> ProcessRequest {
        guard let gdbCommands else { return ProcessRequest(.path(program.path)) }
        return ProcessRequest(
            .name("gdb"), arguments: ["-batch", "-x", gdbCommands.path, "--args", program.path],
            environment: ProcessEnvironment.inherited.setting("SWIFT_BACKTRACE", to: "enable=no"))
    }
}
