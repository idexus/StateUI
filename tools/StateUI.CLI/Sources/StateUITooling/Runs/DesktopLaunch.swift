// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A GTK or WinUI head of this machine started from its program and followed until it ends, its output told as it
/// comes - what a guest of a Mac runs when the Mac asks it. A GTK head is installed first and a copy of it running
/// stopped: a GTK application is one instance. Cancelled, the program is stopped with everything it started.
/// Design: docs/design/tooling/runs.md#a-desktop-head
struct DesktopLaunch: Sendable {
    /// Runs `built`'s program and follows it.
    func run(_ built: BuildResult, reporter: RunReporter) async throws -> RunResult {
        let program = try FileURI.url(built.programUri)
        if built.host == .gtk {
            _ = try await ApplicationInstaller().install(try FileURI.url(built.folderUri))
            _ = try? await ProcessRunner().run(ProcessRequest(.name("pkill"), arguments: ["-f", "^\(program.path)( |$)"]))
        }
        reporter.started(LaunchedApplication(build: built, process: nil, held: false))
        let outcome = try await ProcessRunner().run(ProcessRequest(.path(program.path)), output: reporter.output)
        try Task.checkCancellation()
        return RunResult(launched: LaunchedApplication(build: built, process: nil, held: false), exitStatus: Int(outcome.exitStatus))
    }
}
