// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Darwin
import Foundation
import StateUIToolingProtocol

/// A UIKit head started on a simulator - booted first where it is not - and followed until it ends; a stop ends it.
/// `simctl launch` returns once the application started, its output going to two files the run reads, so no
/// launching process outlives the run.
/// Design: docs/design/tooling/runs.md#on-a-simulator
struct SimulatorLaunch {
    var simulator: Destination
    var bundle: URL
    var identifier: String
    /// The folder the application's two streams are written in.
    var logs: URL
    /// What the run hands the application of the tool's environment.
    var environment: HandedEnvironment

    /// `simctl`'s own environment, handing the application `environment`: simctl hands it each variable named
    /// `SIMCTL_CHILD_<name>` as `<name>`.
    static func environment(handing environment: HandedEnvironment) -> ProcessEnvironment {
        environment.sorted.reduce(ProcessEnvironment.inherited) { $0.setting("SIMCTL_CHILD_\($1.name)", to: $1.value) }
    }

    func run(_ built: BuildResult, held: Bool, reporter: RunReporter) async throws -> RunResult {
        reporter.build.progress("booting \(simulator.name)")
        try await ToolStep.run(.name("xcrun"), ["simctl", "bootstatus", simulator.udid, "-b"], limit: .seconds(300))
        _ = try? await ToolStep.run(.name("open"), ["-a", "Simulator", "--args", "-CurrentDeviceUDID", simulator.udid])
        reporter.build.progress("installing on \(simulator.name)")
        try await ToolStep.run(.name("xcrun"), ["simctl", "install", simulator.udid, bundle.path], limit: .seconds(300))

        let files = FileManager.default
        try files.createDirectory(at: logs, withIntermediateDirectories: true)
        let (out, err) = (logs.appendingPathComponent("stdout.log"), logs.appendingPathComponent("stderr.log"))
        for file in [out, err] { try? files.removeItem(at: file) }
        reporter.build.progress("starting \(identifier)")
        let process = try await launch(held: held, out: out, err: err)
        let launched = LaunchedApplication(
            build: built, process: process, held: held, debugger: held ? DebugDescriptors.simulator(process: process) : nil)
        reporter.started(launched)

        var tails = [FileTail(out, as: .standardOutput), FileTail(err, as: .standardError)]
        while Self.alive(process) {
            if Task.isCancelled {
                await ToolStep.regardless(.name("xcrun"), ["simctl", "terminate", simulator.udid, identifier])
                for index in tails.indices { tails[index].read(end: true).forEach(reporter.output) }
                throw CancellationError()
            }
            for index in tails.indices { tails[index].read().forEach(reporter.output) }
            try? await Task.sleep(for: .milliseconds(200))
        }
        for index in tails.indices { tails[index].read(end: true).forEach(reporter.output) }
        return RunResult(launched: launched, exitStatus: nil)
    }

    /// The process `simctl launch` started of the application, its two streams written to `out` and `err`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with what simctl said and how it ended, where it started none.
    func launch(held: Bool, out: URL, err: URL) async throws -> Int {
        let said: String
        do {
            said = try await ToolStep.run(.name("xcrun"), ["simctl", "launch", "--terminate-running-process"]
                + (held ? ["--wait-for-debugger"] : []) + ["--stdout=\(out.path)", "--stderr=\(err.path)", simulator.udid, identifier],
                environment: Self.environment(handing: environment), limit: .seconds(60))
        } catch let refused as ToolingError {
            throw ToolingError(.toolFailed, "\(identifier) did not start on \(simulator.name): \(refused.message)\nWhere"
                + " `xcrun simctl spawn \(simulator.udid) launchctl list` still lists it, an earlier process of it never"
                + " ended - one a stopped debugserver holds.")
        }
        guard let process = said.split(separator: ":").last.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) else {
            throw ToolingError(.toolFailed, "\(identifier) did not start on \(simulator.name): simctl launch named no process"
                + " - it said \"\(said)\"")
        }
        return process
    }

    /// Whether process `process` of this Mac still runs - a held one too.
    static func alive(_ process: Int) -> Bool {
        kill(pid_t(process), 0) == 0 || errno == EPERM
    }
}
#endif
